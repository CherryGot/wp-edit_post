#!/bin/bash

# Check if exactly one argument is provided
if [ $# -ne 1 ]; then
  echo "Error: Please provide exactly one argument and make sure it's a valid 'version' string."
  exit 1
fi

# Define a pattern for a version string (e.g., "x.y.z")
version_pattern="^[0-9]+\.[0-9]+\.[0-9]+$"

# Check if the argument matches the version pattern
if ! [[ $1 =~ $version_pattern ]]; then
  echo "Error: Provided argument is not a valid version string (x.y.z format)."
  exit 1
fi

# Extracting MAJOR from the version string
MAJOR=$(echo $1 | cut -d'.' -f1)
# Checking if the branch exists
if ! git show-ref --quiet refs/heads/wp-edit_post/v${MAJOR}; then
  echo "Branch wp-edit_post/v${MAJOR} can not be found. We need that branch before loading the latest commits."
  exit 2
fi

# Checkout to this update specific branch.
git checkout wp-edit_post/v${MAJOR}
git checkout -b chores/update/@wordpress/edit-post@$1

# Creating temporary directory to clone the remote gutenberg repo.
temp_dir=$(mktemp -d)
git clone --depth 1 --branch @wordpress/edit-post@$1 https://github.com/WordPress/gutenberg.git $temp_dir

# Check the exit status of the clone operation
if [ $? -ne 0 ]; then
  echo "Exiting because of the previous error."

  git checkout wp-edit_post/v${MAJOR}
  git branch -D chores/update/@wordpress/edit-post@$1

  # Remove the temporary directory.
  rm -rf $temp_dir

  exit 3
fi

edit_post_package_json="$temp_dir/packages/edit-post/package.json"

# Function to get the version from a package.json file
get_version() {
  local package_json="$1"
  jq -r '.version' "$package_json"
}

# Iterate through packages and update dependencies in edit-post/package.json
for package_name in a11y api-fetch block-editor block-library blocks commands components compose \
  core-commands core-data data deprecated dom editor element hooks i18n icons \
  interface keyboard-shortcuts keycodes media-utils notices plugins preferences \
  private-apis url viewport warning widgets; do

  # Get the version of the package
  package_version=$(get_version "$temp_dir/packages/$package_name/package.json")

  # Replace the version in edit-post/package.json
  sed -i "s/\"@wordpress\/$package_name\": \".*\"/\"@wordpress\/$package_name\": \"$package_version\"/" "$edit_post_package_json"
done

# Copy the contents of the edit-post package using rsync
rsync -av --exclude='.git' $temp_dir/packages/edit-post/* .

rm -rf $temp_dir
