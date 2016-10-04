# chef_pgtap: CHEF's Custom pgTAP Test Extensions

[pgTAP] is awesome for testing PostgreSQL databases, but sometimes you need some custom testing functions that aren't built into pgTAP yet. `chef_pgtap` is where CHEF currently keeps its custom functions to facilitate their reuse across our various database projects.

`chef_pgtap` is shipped as a [PostgreSQL extension], which is basically a collection of associated database objects that can be treated as a coherent unit.

# Installation

The files that make up the extension are first installed into a shared directory on the database server, and then can be installed into individual databases using the [CREATE EXTENSION] command.

```
make install
```

Then, inside your database:

```sql
CREATE EXTENSION chef_pgtap;
```

# Dependencies

`chef_pgtap` relies on [pgTAP] (as one might expect), and will not install in your database if the [pgTAP] extension is not also present.

# PostgreSQL Extension Cheatsheet

## Adding to the extension

Extension SQL files are named according to the pattern

```
${EXTENSION_NAME}--${FROM_VERSION}--${TO_VERSION}.sql
```

Note that `FROM_VERSION` and `TO_VERSION` can be any string (without hyphens); we use standard SemVer `MAJOR.MINOR.PATCH` version strings. If you want to add new functions, set up an new file named such that it brings the current version up to the new version (i.e., the one with your new functions).

For example, if the latest version is `0.1.0`, and you want to add new features, create a file named `chef_pgtap--0.1.0--0.2.0.sql`.

It's also a good idea to update the `default_version` key in the `chef_pgtap.control` file to reflect the now-updated latest version.

## Useful Commands

```
-- Installs the default version (see chef_pgtap.control)
CREATE EXTENSION chef_pgtap;

-- Install a specific version
CREATE EXTENSION chef_pgtap WITH VERSION '0.2.0';

-- Remove an extension
DROP EXTENSION chef_pgtap;

-- Upgrade an extension
ALTER EXTENSION chef_pgtap UPDATE TO '0.2.0';
```

[create extension]: http://www.postgresql.org/docs/current/static/sql-createextension.html
[pgtap]: http://pgtap.org
[postgresql extension]: http://www.postgresql.org/docs/current/static/extend-extensions.html

## Contributing

For information on contributing to this project see <https://github.com/chef/chef/blob/master/CONTRIBUTING.md>

## License

- Copyright:: 2013-2016 Chef Software, Inc.
- License:: Apache License, Version 2.0

```text
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
