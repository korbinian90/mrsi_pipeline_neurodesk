# Staging the local MATLAB pieces

The development image runs the pipeline's `.m` source rather than the compiled
binaries, so it needs a real MATLAB and the parts of the MATLAB path that are
not in any git repository. Both are staged here and neither is committed.

Nothing here is needed for the shipped image. That one keeps the MATLAB Runtime
and the compiled binaries, and requires no licence.

## What to stage

```
container/matlab_local/
    path/          added to the MATLAB path inside the image
    license.lic    the licence file for this container
```

### `path/`

Directories that `compile.m` expects and that a clone does not provide, because
they are gitignored upstream. Copy them from a checkout that has them:

```
MatlabFunctions/MatlabFunctions_3rdParty/catstruct
MatlabFunctions/MatlabFunctions_3rdParty/fieldnamesr
MatlabFunctions/MatlabFunctions_3rdParty/mapVBVD
MatlabFunctions/MatlabFunctions_3rdParty/stringdist
MatlabFunctions/MatlabFunctions_3rdParty/Lipid_Suppression_Toolbox_CodeOnly
MatlabFunctions/ToolboxCopies/IndividualFunctions
```

Without `mapVBVD` the raw Siemens reader is missing and nothing reads a `.dat`.
Without the others, `compile.m` silently produces binaries that are missing
their dependencies, because `dir()` on a path that is not there returns empty
rather than failing.

### `license.lic`

See "Licence" below. It is tied to one host ID and one user name, so it is
specific to this container and must not be shared or committed.

## Licence

The image is built with MATLAB installed, which needs a licence at run time.
Obtain a file through the MathWorks License Center:

1. Sign in, open **License Center**, select the licence.
2. Under **Related Tasks**, choose **Activate to Retrieve License File**.
3. Supply:
   - **Release**: the release the image installs (see `MATLAB_RELEASE` in
     `Dockerfile.matlab-dev`)
   - **Operating system**: Linux, 64 bit
   - **Host ID**: the container's MAC address without separators. It is fixed
     by `matlab_shell.sh`, which prints it, so the value is known in advance
     rather than discovered.
   - **User name**: the login that starts MATLAB inside the container. It is
     case sensitive and must match exactly, or MATLAB fails with Error 9.
     `matlab_shell.sh` prints this too.
4. Download `license.lic` into this directory.

The licence never enters the image. `matlab_shell.sh` mounts it read only and
pins the MAC, so the same file keeps working across container restarts, which it
would not if Docker assigned a random address each time.
