# Fission Nellie

Execute commands on repository of code

## Usage (user)

Commands are provided in a `.nellie` file at the root of the
project repository.

### Bash script

The `.nellie` file can be a bash script that is executed directly:

```bash
#!/bin/bash

/usr/bin/true
```

### JSON file

The `.nellie` file can be a JSON script to provide multiple commands
as well as environment variables:

```json
{
  "commands": [
    "/bin/true",
    "echo 'YAY!'"
  ],
  "environment": {
    "FOOBAR": "enabled"
  }
}
```

## Usage (operator)

### Pending status

Nellie can be configured to generate status payloads while a job
is in process.

```json
{
  "nellie": {
    "status": {
      "interval": 2,
      "source": "nellie_webhook"
    }
  }
}
```

This will enable notifications on jobs being executed. Options:

* `interval` wait interval between notifications (can be subsecond)
* `source` source that the notificiation payload will be delivered

## Originating slogan

Fuck Jenkins!