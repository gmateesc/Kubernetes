## Deploy ARM template with az CLI

```bash
az deployment group create \
	       --resource-group $RESOURCE_GROUP  \
	       --template-file akstemplate.json  \
	       --parameter @akstemplate.parameters.json
```
