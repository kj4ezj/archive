# archive
Both `rsync` and `scp` will overwrite files that exist in the destination. The `archive.sh` BASH script wraps `rsync` to test if files exist before sending them to the destination, and provides ancillary services useful for digitizing documents.

<!-- contents box begin -->
<table>
<tr/>
<tr>
<td width="300">
<p/>
<div align="center">
<b>Contents</b>
</div>
<p/>
<!-- contents markdown begin -->

1. [Installation](#installation)
    1. [bpkg](#bpkg)
    1. [Manual](#manual)
1. [Development](#development)
    1. [Lint](#lint)
    1. [CI](#ci)
1. [See Also](#see-also)

<!-- contents markdown end -->
<p/>
</td>
</tr>
</table>
<!-- contents box end -->

## Installation
Install [bpkg](https://github.com/bpkg/bpkg) if you have not already.

> [!IMPORTANT]
> > If you are on **macOS** or **BSD** then you will need to [default to GNU tools](https://apple.stackexchange.com/a/69332) in your environment. You can check this by running `grep --version`, which will tell you whether it is BSD or GNU `grep`.

### bpkg
This is the recommended installation method.

Install the [echo-eval](https://github.com/kj4ezj/echo-eval) dependency.
```bash
sudo bpkg install -g kj4ezj/ee
```
Then, install this tool using `bpkg`.
```bash
sudo bpkg install kj4ezj/archive
```
This does a global install so `archive` should now be in your system `PATH`.

### Manual
Clone this repo locally with `git` using your preferred method. Install project dependencies.
```bash
bpkg install
```
You can invoke the script directly from your copy of the repo.

## Development
Contributors need these tools installed.
- [act](https://github.com/nektos/act)
    - docker
- [bpkg](https://github.com/bpkg/bpkg)
    - git
    - make
- [git](https://git-scm.com)
- [GNU tools](https://apple.stackexchange.com/a/69332)

Please [sign your commits](https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-commits).

### Init
Clone this repo locally with `git` using your preferred method, then install project dependencies.
```bash
bpkg install --dev
```

### Lint
This project uses [bashate](https://github.com/openstack/bashate) _and_ [shellcheck](https://github.com/koalaman/shellcheck) for linting.
```bash
bpkg run lint
```
This invokes `lint.sh` which contains the specific configuration for each permutation of linter and target file.

### CI
This repo uses GitHub Actions workflows for CI.
1. **archive.sh CI** - initialize and lint the `archive.sh` project.
    - [Pipeline](https://github.com/kj4ezj/archive/actions/workflows/ci.yml)
    - [Documentation](./.github/workflows/README.md)

> [!IMPORTANT]
> > The CI must pass before a pull request will be peer-reviewed.

You can run the GitHub Actions workflow(s) locally using [act](https://github.com/nektos/act).
```bash
bpkg run act
```
Please make sure any pipeline changes do not break `act` compatibility.

## See Also
- [bpkg](https://bpkg.sh)
    - [echo-eval](https://bpkg.sh/pkg/echo-eval)
        - [GitHub](https://github.com/kj4ezj/echo-eval)
    - [GitHub](https://github.com/bpkg)

***
> **_Legal Notice_**  
> This repo contains assets created in collaboration with a large language model, machine learning algorithm, or weak artificial intelligence (AI). This notice is required in some countries.
