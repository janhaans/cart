# Use Codex (OpenAI) to deploy a .NET webapplication in Azure

This is an exercise to learn how Codex can be used to deploy a simple .NET web application on Azure AKS. Azure AKS is not really required for such a simple web application, but is just for fun.

Given is the .NET 8 code in `/src` folder

## Create prompt to give instructions to create Infrastructure as Code (BICEP for ACR and AKS)

Using ChatGPT the following prompt has been created

```
You are an expert Azure cloud architect and Bicep author.

Goal:
I have a .NET 8 web application whose code lives in the `/src` folder of my repository. I want to deploy it to a public-facing Azure Kubernetes Service (AKS) cluster. I want you to write Bicep infrastructure-as-code that provisions the necessary Azure resources:

- Resource group
- Azure Container Registry (ACR)
- A small AKS cluster that is suitable for dev/test
- (Optionally) Log Analytics workspace and monitoring configuration for AKS

Requirements:

1. Use **Bicep** only.
2. Provide a **single main.bicep** file (you may use modules if you want, but they should all be included in the output).
3. The AKS cluster will later be used to deploy a single .NET 8 web app container built from the `/src` folder. Assume the container image will live in the ACR you create here.

Bicep details:

- Make the template reusable with **parameters** for:
  - `location`
  - `projectName` (used in naming ACR, AKS, etc.)
  - `environment` (e.g. `dev`, `test`)
  - `nodeCount` and `nodeVmSize` for AKS
- Use sensible default values (e.g. `location = 'westeurope'`, small node size, 1–2 nodes).
- ACR:
  - Use a standard SKU suitable for dev/test.
  - Ensure the AKS cluster is allowed to pull images from this ACR (use managed identity or identity-based access; do NOT hard-code credentials).
- AKS:
  - Use a system-assigned managed identity.
  - Enable RBAC.
  - Configure networking with default/basic settings (no overly complex custom VNETs).
- Outputs:
  - Output the AKS cluster name.
  - Output the ACR login server name.
  - Output any other identifiers that will be useful in a CI/CD pipeline (e.g. resource group name, AKS resource ID).

What to return:

- Return ONLY Bicep code in one or more code blocks.
- The main file must be named **`main.bicep`** (put that in a comment at the top of the main file).
- If you define any module files, show each module in a separate code block and start each one with a comment that contains the file name, e.g. `// acr.bicep`.
- Do not include explanations or prose outside of short comments in the Bicep files themselves.
```

Codex outputs 2 Bicep templates

- `main.bicep`
- `aks-infra.bicep` (ACR and AKS)

Next prompt I ask Codex to create these files

```
Create a bicep folder and place main.bicep in this folder. Place aks-infra.bicep in modules subfolder and change main.bicep file accordingly
```

I see that the folder structure and bicep files have been created.
Bicep linter gives one error and 2 warnings in file `aks-infra.bicep`. I use Github Copilot to solve the error and warning. Also Codex chat can be used to fix issues.

Now I wanted Codex to create an bash script to deploy the Bicep files. Therefor I created the prompt

```
Create a bash script named "deploy-infra.sh" in the root folder using azure CLI to login into an Azure subscription if not already logged in and deploy the bicep.main template
```

Bash script `deploy-infra.sh` has been created. Now, I deploy the infra:

```
chmod +x deploy-infra.sh
./deploy-infra.sh -p cart
```

**IT WORKS!**
Two Resource Groups are created:

- `cart-dev-rg`
- `MC_cart-dev-rg_cart-dev-aks_westeurope` (Azure created this second resource group automatically for AKS and is AKS managed. It holds the Kubernetes cluster underlying infrastructure (VM scale sets, NIC's load balancer, managed identity resources, public IPs))

Now I want to destroy the provisioned infra, so I created the prompt:

```
Create a bash script named "destroy-infra.sh" in the root folder using azure CLI to login into an Azure subscription if not already logged in and destroy the Azure Resource Group that has been created by the deployment of bash script "deploy-infra.sh"
```

Bash script `destroy-infra.sh` has been created. Now, I destroy the infra:

```
chmod +x destroy-infra.sh
./destroy-infra.sh -p cart
```

**IT WORKS!**
Both Resource Groups are destroyed:

- `cart-dev-rg`
- `MC_cart-dev-rg_cart-dev-aks_westeurope`
