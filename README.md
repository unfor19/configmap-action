# configmap-action

Exports a ConfigMap as an [output](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idoutputs) according to a given key, such as `GIT_BRANCH` or `DEPLOYMENT_ENVIRONMENT` and consume it in other jobs ([needs](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idneeds)).

## Usage

1. Create a [configmap.json](./configmap.json) in your git repository
2. (WIP) Add the following job to the top of your existing workflow
   ```yaml
   prepare:
     runs-on: ubuntu-20.04
     name: Prepare ${{ github.event.inputs.src_repository }}
     steps:
       - uses: actions/checkout@v2
       # Assuming you have a `configmap.json` in your repo
       - name: Set Configmap
         env:
           CONFIGMAP_FILE_PATH: configmap.json
         id: set-configmap
         run: |
           echo "::set-output name=configmap::$(jq -c . ${{ env.CONFIGMAP_FILE_PATH }})"
       - name: Export Configmap
         continue-on-error: true # Allow failure, a status update will be sent to source repo
         with:
           configmap: ${{ steps.set-configmap.outputs.configmap }}
         id: export-configmap
         uses: unfor19/configmap-action@development
        ### Required outputs - feel free to add your own outputs
        ### -----------------------------------------------------
      outputs:
        CONFIGMAP: ${{ steps.export-configmap.outputs.CONFIGMAP_MAP }}
        DEPLOYMENT_ENVIRONMENT: ${{ steps.export-configmap.outputs.CONFIGMAP_SELECTED_KEY }}
        ### -----------------------------------------------------
   ```
3. Consume as env var in your step
   ```yaml
    env:
        APP_NAME: ${{ matrix.configmap.APP_NAME }}
   ```

### Adding a new Secret

1. (Optional) Create a secret per env in GitHub Actions
   - AWS_ACCESS_KEY_ID_DEVELOPMENT
   - AWS_SECRET_ACCESS_KEY_DEVELOPMENT
   - AWS_ACCESS_KEY_ID_STAGING
   - AWS_SECRET_ACCESS_KEY_STAGING
   - AWS_ACCESS_KEY_ID_PRODUCTION
   - AWS_SECRET_ACCESS_KEY_PRODUCTION
1. (WIP) Add a ref to secret name in `env` of the following job, and then consume it with `secrets[env.AWS_ACCESS_KEY_ID_NAME]`


## Authors

Created and maintained by [Meir Gabay](https://github.com/unfor19)

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/unfor19/configmap-action/blob/master/LICENSE) file for details
