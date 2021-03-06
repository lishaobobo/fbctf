#!/bin/bash
#
# Facebook CTF: script to start tests and code coverage
#
# Usage: ./run_tests.sh [path_to_code]
#

set -e

DB="fbctftests"
CODE_PATH=${1:-/vagrant}
DB_USER=${2:-root}
DB_PWD=${3:-root}

echo "[+] Starting tests setup in $CODE_PATH"

mysql -u "$DB_USER" --password="$DB_PWD" -e "CREATE DATABASE $DB;"
mysql -u "$DB_USER" --password="$DB_PWD" -e "FLUSH PRIVILEGES;"
mysql -u "$DB_USER" --password="$DB_PWD" "$DB" -e "source $CODE_PATH/database/test_schema.sql;"
mysql -u "$DB_USER" --password="$DB_PWD" "$DB" -e "source $CODE_PATH/database/logos.sql;"
mysql -u "$DB_USER" --password="$DB_PWD" "$DB" -e "source $CODE_PATH/database/countries.sql;"

if [ -f "$CODE_PATH/settings.ini" ]; then
  echo "[+] Backing up existing settings.ini"
  sudo cp "$CODE_PATH/settings.ini" "$CODE_PATH/settings.ini.bak"
fi

# Because this is a test suite we assume you are running on a single server, if not update the DB and MC addresses...
echo "[+] DB Connection file"
cat "$CODE_PATH/extra/settings.ini.example" | sed "s/DATABASE/$DB/g" | sed "s/MYUSER/$DB_USER/g" | sed "s/MYPWD/$DB_PWD/g" | sed "s/DBHOST/127.0.0.1/g" | sed "s/MCHOST/127.0.0.1/g" | sudo tee "$CODE_PATH/settings.ini"

echo "[+] Starting tests"
hhvm vendor/phpunit/phpunit/phpunit tests

echo "[+] Deleting test database"
mysql -u "$DB_USER" --password="$DB_PWD" -e "DROP DATABASE IF EXISTS $DB;"
mysql -u "$DB_USER" --password="$DB_PWD" -e "FLUSH PRIVILEGES;"

if [ -f "$CODE_PATH/settings.ini.bak" ]; then
  echo "[+] Restoring previous settings.ini"
  sudo mv "$CODE_PATH/settings.ini.bak" "$CODE_PATH/settings.ini"
fi

# In the future, we should use the hh_client exit status.
# Current there are some PHP built-ins not found in the hhi files upstream in HHVM.
echo "[+] Verifying HHVM Strict Compliance and Error Checking"
if [[ $(hh_client $CODE_PATH | grep -vP "Unbound" | wc -l) != 0 ]]; then
  hh_client $CODE_PATH
  exit 1
fi
