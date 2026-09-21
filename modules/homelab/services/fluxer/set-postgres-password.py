"""Set the database password without shell expansion or secret command arguments."""

import os
from pathlib import Path
import subprocess


credential = Path(os.environ['CREDENTIALS_DIRECTORY']) / 'postgres-env'
key, separator, password = credential.read_text().rstrip('\n').partition('=')
if key != 'POSTGRES_PASSWORD' or not separator or not password or '\n' in password:
    raise ValueError('Invalid Fluxer PostgreSQL credential')

subprocess.run(
    ['psql', '-X', '--no-password', '-v', 'ON_ERROR_STOP=1', '-d', 'postgres'],
    input="""\
SET log_statement = 'none';
SET log_min_duration_statement = -1;
SET password_encryption = 'scram-sha-256';
\\getenv password POSTGRES_PASSWORD
ALTER ROLE fluxer PASSWORD :'password';
""",
    text=True,
    env={**os.environ, 'POSTGRES_PASSWORD': password},
    check=True,
)
