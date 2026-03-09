# Project configs (znuny-dev)

Optional configuration files can be placed in this directory.

## Subdirectories

- **`configs/instance/`** – Instance/environment settings  
  - **`instance/my.env`** – Loaded after the global `.env` and overrides values set there (e.g. repository URLs).

- **`configs/framework/`** – Framework settings (Kernel/Config.pm)  
  - **`framework/Config.pm`** – Optional; its content is injected into each instance’s `Kernel/Config.pm` on container start (see below).

## Config.pm – custom settings

You can create **`configs/framework/Config.pm`**. Its content is injected into each instance’s `Kernel/Config.pm` on start – into the block between these markers:

- `# insert your own config settings "here"`
- `# end of your own config options!!!`

### Content

Only lines as in `Kernel/Config/Defaults.pm` or the existing Config.pm, e.g. `$Self->{...} = ...;`. Do not put database or structural changes here; use instance and DB configuration for that.

### Example `configs/framework/Config.pm`

```perl
# Optional: only $Self->{...} = ... lines, e.g. from Kernel/Config/Defaults.pm
$Self->{'SwitchToAgent'}    = 1;
$Self->{'SwitchToCustomer'} = 1;
$Self->{'Loader::Enabled::CSS'} = 0;
$Self->{'Loader::Enabled::JS'}  = 0;
```

### When does it take effect?

After creating or changing `configs/framework/Config.pm`, on the next container start (or on each run of `setup_framework_config` in startup) the content is injected into the respective `Kernel/Config.pm`, or the block between the markers is replaced by the current content of `configs/framework/Config.pm`.

If a framework’s `Config.pm` does not contain the marker block above, no snippet injection is performed.
