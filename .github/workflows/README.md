# archive.sh CI
This GitHub Actions workflow initializes and lints the `archive.sh` project.

### Index
1. [Triggers](#triggers)
1. [Inputs](#inputs)
1. [Steps](#steps)
1. [Outputs](#outputs)
1. [See Also](#see-also)

## Triggers
This GitHub action will run under the following circumstances:
1. When code is pushed.
1. When a pull request is opened.
1. On a workflow dispatch event, a manual CI run which can be triggered by the "Workflow Dispatch" button on the "Actions" tab of the GitHub repository, among other means.

## Inputs
There are currently no user-defined inputs for this pipeline, aside from the source code itself.

## Steps
This workflow performs the following steps on GitHub runners:
1. Attach Documentation
    1. Checkout this repo with no submodules.
    1. Attach an annotation to the GitHub Actions build summary page containing CI documentation.
1. Lint `archive.sh`
    1. Checkout this repo.
    1. Install system dependencies using `.github/workflows/deps.sh`.
    1. Initialize the project using `bpkg install --dev`.
    1. Lint the project with `shellcheck` and `bashate` by running `bpkg run lint`.

## Outputs
There are currently no outputs of this GitHub Actions workflow, besides the exit status.

## See Also
- [archive.sh Documentation](../../README.md)

For assistance with the CI system, please open an issue in this repo.

***
> **_Legal Notice_**  
> This document was created in collaboration with a large language model, machine learning algorithm, or weak artificial intelligence (AI). This notice is required in some countries.
