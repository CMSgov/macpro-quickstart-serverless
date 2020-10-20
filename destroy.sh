#!/bin/bash
set -e

if [[ $1 == "" ]] ; then
    echo 'ERROR:  You must pass a stage to destroy.  Ex. sh destroy.sh my-stage-name'
    exit 1
fi
stage=$1

echo "\nCollecting information on stage $stage before attempting a destroy... This can take a minute or two..."

# Find buckets associated with stage
# Unfortunately, I can't get all buckets and all associaged tags in a single CLI call (that I know of)
# So this can be pretty slow, depending on how many buckets exist in the account
# We get all bucket names, then find associated tags for each one-by-one
bucketList=(`aws s3api list-buckets --output text --query 'Buckets[*].Name'` )
filteredBucketList=()
for i in "${bucketList[@]}"
do
  stage_tag=`aws s3api get-bucket-tagging --bucket $i --output text --query 'TagSet[?Key==\`STAGE\`].Value'`
  if [ "$stage_tag" == "$stage" ]; then
    filteredBucketList+=($i)
  fi
done

# Find cloudformation stacks associated with stage
filteredStackList=(`aws cloudformation describe-stacks | jq -r ".Stacks[] | select(.Tags[] | select(.Key==\"STAGE\") | select(.Value==\"$stage\")) | .StackName"`)


echo """
********************************************************************************
- Check the following carefully -
********************************************************************************
"""

echo "The following buckets will be emptied"
printf '%s\n' "${filteredBucketList[@]}"

echo "\nThe following stacks will be destroyed:"
printf '%s\n' "${filteredStackList[@]}"

echo """
********************************************************************************
- Scroll up and check carefully -
********************************************************************************
"""

read -p "Do you wish to continue?  Re-enter the stage name to continue:  " -r
echo
if [[ ! $REPLY == "$stage" ]]
then
    echo "Stage name not re-entered.  Doing nothing and exiting."
    exit 1
fi


for i in "${filteredBucketList[@]}"
do
  echo $i
  aws s3 rm s3://$i/ --recursive
done


for i in "${filteredStackList[@]}"
do
  echo $i
  aws cloudformation delete-stack --stack-name $i
done
