#!/bin/bash

# Login to Azure
az login

# Prompt for the necessary input
read -p "Enter the name of your offer: " mspOfferName
read -p "Enter the description of your offer: " mspOfferDescription
read -p "Enter the tenant id of the Managed Service Provider: " managedByTenantId
read -p "Enter the principalId: " principalId
read -p "Enter a display name for the App Registration (optional): " principalIdDisplayName

# Create the authorizations array
authorizations="[
    {'principalId': '$principalId', 'roleDefinitionId': '749f88d5-cbae-40b8-bcfc-e573ddc772fa', 'principalIdDisplayName': '$principalIdDisplayName'},
    {'principalId': '$principalId', 'roleDefinitionId': '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1', 'principalIdDisplayName': '$principalIdDisplayName'}
]"

# Create the JSON file
cat > parameters.json << EOF
{
    "\$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "mspOfferName": {
            "value": "$mspOfferName"
        },
        "mspOfferDescription": {
            "value": "$mspOfferDescription"
        },
        "managedByTenantId": {
            "value": "$managedByTenantId"
        },
        "authorizations": {
            "value": $authorizations
        }
    }
}
EOF

# Rest of the script...


# Check if JSON file was created successfully
if [ $? -eq 0 ]; then
    echo "Successfully created JSON file."
else
    echo "Failed to create JSON file. Exiting script."
    exit 1
fi

# Stage 2: Log in to Azure

# Prompt for Azure login
az login

# Check if login was successful
if [ $? -eq 0 ]; then
    echo "Successfully logged in."
else
    echo "Failed to log in. Exiting script."
    exit 1
fi

# Stage 3: Deploy the JSON file to client's environment

# Get a list of all subscription IDs
subscription_ids=$(az account list --query "[].id" -o tsv)

# Create an array to hold the selected subscription IDs
selected_subscription_ids=()

echo "Select the subscription(s) to which you want to deploy the template:"
echo "(You can select more than one subscription by running this script multiple times, or select 'All' to deploy to all subscriptions.)"
select opt in $subscription_ids "All"
do
    case $opt in
        "All")
            echo "You have selected to deploy to all subscriptions."
            selected_subscription_ids=($subscription_ids)
            break
            ;;
        *)
            if [[ $subscription_ids =~ $opt ]]
            then
                echo "You have selected subscription $opt."
                selected_subscription_ids+=($opt)
            else
                echo "Invalid option. Please try again."
            fi
            ;;
    esac

    # Ask the user if they want to select another subscription
    read -p "Do you want to select another subscription? (y/n) " response
    if [[ $response =~ ^[Nn]o?$ ]]
    then
        break
    fi
done

# Deploy the ARM template to the selected subscriptions
for sub_id in "${selected_subscription_ids[@]}"
do
    echo "Deploying to subscription $sub_id..."
    az account set --subscription $sub_id
    az deployment sub create \
        --name MyManagedServicesDeployment \
        --location <location> \
        --template-file ./subscription.json \
        --parameters mspOfferName=$mspOfferName mspOfferDescription=$mspOfferDescription managedByTenantId=$managedByTenantId authorizations="$authorizations"

    # Check if deployment was successful
    if [ $? -eq 0 ]; then
        echo "Successfully deployed to subscription $sub_id."
    else
        echo "Failed to deploy to subscription $sub_id. Check the error message above."
    fi
done
