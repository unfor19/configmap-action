# configmap-action

[![testing](https://github.com/unfor19/configmap-action/workflows/testing/badge.svg)](https://github.com/unfor19/configmap-action/actions?query=workflow%3Atesting)
[![test-action](https://github.com/unfor19/configmap-action-test/workflows/test-action/badge.svg)](https://github.com/unfor19/configmap-action-test/actions?query=workflow%3Atest-action)


Exports a ConfigMap as an [output](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idoutputs) according to a given key, such as `GIT_BRANCH` or `DEPLOYMENT_ENVIRONMENT` and consume it in other jobs ([needs](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idneeds)).

Tested in [unfor19/configmap-action-test](https://github.com/unfor19/configmap-action-test/actions?query=workflow%3Atest-action)

## Requirements

GitHub's Linux [ubuntu-20.04](https://github.com/actions/virtual-environments/blob/main/images/linux/Ubuntu2004-Readme.md) runners include the below requirements.

1. [Bash v4.4+](https://www.gnu.org/software/bash/)
2. [jq v1.6+](https://stedolan.github.io/jq/)

> **NOTE**: If you're using [Self-Hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners), make sure you have the above requirements installed on the runner.

> **TODO**: Create a new repo that builds a new version of the Docker image [summerwind/actions-runner:latest](https://github.com/actions-runner-controller/actions-runner-controller#software-installed-in-the-runner-image). That will ease the process of implementing this action when using [actions-runner-controller](https://github.com/actions-runner-controller/actions-runner-controller#software-installed-in-the-runner-image).


## Usage

1. Create a [configmap.json](./configmap.json) in your git repository
2. Add the following job to the top of an existing workflow; I'm using [github.ref_name](https://docs.github.com/en/actions/learn-github-actions/contexts#:~:text=github.ref_name) to dynamically select the relevant configmap per environment.
   ```yaml
   prepare:
     runs-on: ubuntu-20.04
     name: Prepare ${{ github.event.inputs.src_repository }}
     steps:
       - uses: actions/checkout@v2
       # Assuming `configmap.json` exists in the git repo
       - name: Set Configmap
         env:
           CONFIGMAP_FILE_PATH: configmap.json
         id: set-configmap
         run: |
           echo "::set-output name=configmap::$(jq -c . ${{ env.CONFIGMAP_FILE_PATH }})"
       - name: Export Configmap
         with:
           configmap_map: ${{ steps.set-configmap.outputs.configmap }}
           configmap_key: ${{ github.ref_name }} # The branch or tag name that triggered the workflow run
         id: export-configmap
         uses: unfor19/configmap-action@development
      ### Required outputs - feel free to add more outputs
      ### -----------------------------------------------------
      outputs:
        CONFIGMAP: ${{ steps.export-configmap.outputs.CONFIGMAP_MAP }}
        CONFIGMAP_SELECTED_KEY: ${{ steps.export-configmap.outputs.CONFIGMAP_SELECTED_KEY }}
      ### -----------------------------------------------------
   ```
3. Consume `prepare`'s output `CONFIGMAP` as a [matrix](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstrategymatrix) in existing jobs, such as `build`
   ```yaml
   build:
     runs-on: ubuntu-20.04
     name: Build ${{ matrix.configmap.NODE_VERSION }}
     ### Add the following block to each job
     ### -----------------------------------------------------
     needs:
       - prepare
     strategy:
       matrix:
         configmap: ${{ fromJSON(needs.prepare.outputs.CONFIGMAP) }}
     ### -----------------------------------------------------
     steps:
       - uses: actions/checkout@v2
       # Inject relevant variables per step
       - name: Get env vars
         env:
           NODE_ENV: ${{ matrix.configmap.NODE_ENV }}
           NODE_VERSION: ${{ matrix.configmap.NODE_VERSION }}
         run: |
           echo "$NODE_ENV"
           echo "$NODE_VERSION"
   ```

### Consuming GitHub Actions Secrets

Secrets **names** are exposed to all steps in a job, though values of secrets can be selectively injected to relevant steps, see example below.

1. Assuming `configmap.json` contains the following secrets names
   ```json
   {
     "production": [
       {
         ...
         "AWS_ACCESS_KEY_ID_NAME": "AWS_ACCESS_KEY_ID_PRODUCTION",
         "AWS_SECRET_ACCESS_KEY_NAME": "AWS_SECRET_ACCESS_KEY_PRODUCTION"
       }
     ],
     "development": [
       {
         ...
         "AWS_ACCESS_KEY_ID_NAME": "AWS_ACCESS_KEY_ID_DEVELOPMENT",
         "AWS_SECRET_ACCESS_KEY_NAME": "AWS_SECRET_ACCESS_KEY_DEVELOPMENT"
       }
     ]
   }
   ```
2. Create secrets per environment (development, staging, production, etc.) in GitHub Actions
   - AWS_ACCESS_KEY_ID_DEVELOPMENT
   - AWS_SECRET_ACCESS_KEY_DEVELOPMENT
   - AWS_ACCESS_KEY_ID_PRODUCTION
   - AWS_SECRET_ACCESS_KEY_PRODUCTION
3. Consume secrets as environment variables with `secrets[matrix.configmap.SECRET_NAME]`.
   ```yaml
     deploy:
       runs-on: ubuntu-20.04
       name: Deploy to ${{ needs.prepare.outputs.CONFIGMAP_SELECTED_KEY }}
       if: ${{ always() }}
       ### Add the following condition to skip deployments for non-environment branches
       # if: |
       #   always() &&
       #   needs.prepare.outputs.CONFIGMAP_SELECTED_KEY != '' &&
       #   needs.prepare.outputs.CONFIGMAP_SELECTED_KEY != 'default' &&
       #   github.event_name == 'push'
       ### Add the following block to each job
       ### -----------------------------------------------------
       needs:
         - prepare
         - build
       strategy:
         matrix:
           configmap: ${{ fromJSON(needs.prepare.outputs.CONFIGMAP) }}
       env:
         DEPLOYMENT_ENVIRONMENT: ${{ needs.prepare.outputs.CONFIGMAP_SELECTED_KEY }}
       ### -----------------------------------------------------
       steps:
         - uses: actions/checkout@v2
         # Inject relevant variables per step
         - name: Get env vars
           env:
             AWS_ACCESS_KEY_ID: ${{ secrets[matrix.configmap.AWS_ACCESS_KEY_ID_NAME] }}
             AWS_SECRET_ACCESS_KEY: ${{ secrets[matrix.configmap.AWS_SECRET_ACCESS_KEY_NAME] }}
           run: |
             echo "Deploying to $DEPLOYMENT_ENVIRONMENT"
             echo "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID"
             echo "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"
   ```


## Authors

Created and maintained by [Meir Gabay](https://github.com/unfor19)

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/unfor19/configmap-action/blob/master/LICENSE) file for details
