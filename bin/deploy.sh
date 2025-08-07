#!/bin/bash

# Define variables
ECS_CLUSTER_NAME="golden-phoenix-ecs"
ECS_SERVICE_NAME="$1"
AWS_REGION="ap-southeast-1"
NEW_IMAGE_TAG="$2" # e.g., latest, a specific version, or a build number
ECR_REPOSITORY_URI="057493959474.dkr.ecr.$AWS_REGION.amazonaws.com/golden-phoenix" # e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/your-repo-name
TASK_DEFINITION_NAME="$1" # The base task definition name

# 1. Get the current active task definition ARN
echo "Getting current active task definition for service: $ECS_SERVICE_NAME"
CURRENT_TASK_DEFINITION_ARN=$(aws ecs describe-services \
    --cluster "$ECS_CLUSTER_NAME" \
    --services "$ECS_SERVICE_NAME" \
    --region "$AWS_REGION" \
    --query 'services[0].taskDefinition' \
    --output text)

if [ -z "$CURRENT_TASK_DEFINITION_ARN" ]; then
    echo "Error: Could not retrieve current task definition ARN."
    exit 1
fi

echo "Current Task Definition ARN: $CURRENT_TASK_DEFINITION_ARN"

# 2. Describe the current task definition to get its JSON content
echo "Describing current task definition..."
TASK_DEFINITION_JSON=$(aws ecs describe-task-definition \
    --task-definition "$CURRENT_TASK_DEFINITION_ARN" \
    --region "$AWS_REGION" \
    --query 'taskDefinition' \
    --output json)

if [ -z "$TASK_DEFINITION_JSON" ]; then
    echo "Error: Could not retrieve task definition JSON."
    exit 1
fi

# 3. Update the image tag in the task definition JSON
# This assumes you have 'jq' installed for JSON manipulation.
echo "Updating image tag in task definition..."
UPDATED_TASK_DEFINITION_JSON=$(echo "$TASK_DEFINITION_JSON" | jq \
    --arg image_uri "${ECR_REPOSITORY_URI}:${NEW_IMAGE_TAG}" \
    '.containerDefinitions[0].image = $image_uri | del(.taskDefinitionArn, .revision, .status, .compatibilities, .registeredAt, .registeredBy, .requiresAttributes, .deregisteredAt)')

if [ -z "$UPDATED_TASK_DEFINITION_JSON" ]; then
    echo "Error: Could not update image tag in task definition JSON."
    exit 1
fi

# 4. Register a new task definition revision
echo "Registering new task definition revision..."
NEW_TASK_DEFINITION_ARN=$(aws ecs register-task-definition \
    --cli-input-json "$UPDATED_TASK_DEFINITION_JSON" \
    --region "$AWS_REGION" \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

if [ -z "$NEW_TASK_DEFINITION_ARN" ]; then
    echo "Error: Could not register new task definition."
    exit 1
fi

echo "New Task Definition ARN: $NEW_TASK_DEFINITION_ARN"

# 5. Update the ECS service with the new task definition
echo "Updating ECS service with new task definition..."
aws ecs update-service \
    --cluster "$ECS_CLUSTER_NAME" \
    --service "$ECS_SERVICE_NAME" \
    --task-definition "$NEW_TASK_DEFINITION_ARN" \
    --region "$AWS_REGION" \
    --force-new-deployment # This forces ECS to deploy new tasks with the updated definition

echo "ECS service update initiated. Monitoring deployment status..."

# Optional: Wait for the service to become stable
#aws ecs wait services-stable \
#    --cluster "$ECS_CLUSTER_NAME" \
#    --services "$ECS_SERVICE_NAME" \
#    --region "$AWS_REGION"
#
#echo "Deployment complete and service stable."