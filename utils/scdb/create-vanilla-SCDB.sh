#!/bin/sh
# This script creates a vanilla SCDB from QWG site.
# SCDB itself is download from SVN and the templates are located
# from the various Git repositories holding them.
# The cluster examples are then compiled.
#
# Written by Michel Jouvin <jouvin@lal.in2p3.fr>, 30/9/2013
#

git_url_root=git@github.com:quattor
git_repo_list='core examples grid os standard monitoring'
core_git_repo=template-library-core
examples_git_repo=template-library-examples
grid_git_repo=template-library-grid
os_git_repo=template-library-os
standard_git_repo=template-library-standard
monitoring_git_repo=template-library-monitoring
core_branch_def=.*
examples_branch_def=master
grid_branch_def=umd-3
os_branch_def=.*
standard_branch_def=master
monitoring_branch_def=master
core_dest_dir=cfg/quattor/%BRANCH%
examples_dest_dir=cfg
grid_dest_dir=cfg/grid/%BRANCH%
os_dest_dir=cfg/os/%BRANCH%
standard_dest_dir=cfg/standard
monitoring_dest_dir=cfg/standard/monitoring
git_clone_root=/tmp/quattor-template-library
scdb_dir=/tmp/scdb-vanilla
checkout_templates=0
list_branches=0
remove_scdb=0
externals_root_url=https://svn.lal.in2p3.fr/LCG/QWG/External
panc_version=panc-9.3
ant_version=apache-ant-1.7.1
scdb_ant_utils_version=scdb-ant-utils-9.0.2
svnkit_version=svnkit-1.3.5
# scdb source is typically a clone of GitHub scdb repo, switched to the appropriate
# version/branch. By default, the root of the clone is 2 level upper than the directory
# containing this script (util/scdb)
scdb_source="$(dirname $0)/../.."

usage () {
  echo "usage:  `basename $0` [-F] [-D] [-d scdb_dir] [branch]"
  echo ""
  echo "        -d scdb_dir : directory where to create SCDB."
  echo "                      (D: ${scdb_dir})"
  echo "        -D : debug mode. Checkout rather than export templates"
  echo "        -F : remove scdb_dir if it already exists."
  echo "        -l : list available branches."
  echo "        -S : SCDB source (D: ${scdb_source})"
  echo ""
  exit 1
}


while [ -n "`echo $1 | grep '^-'`" ]
do
  case $1 in
  -d)
    shift
    scdb_dir=$1
    ;;

  -D)
    checkout_templates=1
    ;;

  -l)
    list_branches=1
    ;;

  -F)
    remove_scdb=1
    ;;

  -S)
    shift
    scdb_version=$1
    ;;

  *)
    usage
    ;;
  esac
  shift
done

# If -l has been specified, list available branches and exit
if [ $list_branches -eq 1 ]
then
  git --git-dir ${scdb_source}/.git branch -a
  exit 0
fi


# Check (or remove) the SCDB destination directory.
if [ -d ${scdb_dir} ] 
then
  if [ ${remove_scdb} -eq 0 ]
  then
    echo "Directory $scdb_dir already exists. Remove it or use -F"
    exit
  else
    echo "Removing ${scdb_dir}..."
    rm -Rf ${scdb_dir}
  fi
fi
mkdir -p ${scdb_dir}

# Check (or remove+create) if the destination directory for Git clones exists
if [ -d ${git_clone_root} ]
then
  if [ ${remove_scdb} -eq 0 ]
  then
    echo "Directory ${git_clone_root} already exists. Remove it or use -F"
    exit
  else
    echo "Removing ${git_clone_root}..."
    rm -Rf ${git_clone_root}
  fi
fi
mkdir ${git_clone_root}


echo "Creating vanilla SCDB from $scdb_source in $scdb_dir..."
cp -R ${scdb_source}/* ${scdb_dir}
if [ $? -ne 0 ]
then
  echo "Error creating vanilla SCDB. Aborting..."
  exit 1
fi
echo "Adding panc version ${panc_version}..."
svn export ${externals_root_url}/${panc_version} ${scdb_dir}/external/panc > /dev/null
if [ $? -ne 0 ]
then
  echo "Error adding panc. Aborting..."
  exit 1
fi
echo "Adding ant version ${ant_version}..."
svn export ${externals_root_url}/${ant_version} ${scdb_dir}/external/ant > /dev/null
if [ $? -ne 0 ]
then
  echo "Error adding ant. Aborting..."
  exit 1
fi
echo "Adding scdb-ant-utils version ${scdb_ant_utils_version}..."
svn export ${externals_root_url}/${scdb_ant_utils_version} ${scdb_dir}/external/scdb-ant-utils > /dev/null
if [ $? -ne 0 ]
then
  echo "Error adding scdb-ant-utils. Aborting..."
  exit 1
fi
echo "Adding svnkit version ${svnkit_version}..."
svn export ${externals_root_url}/${svnkit_version} ${scdb_dir}/external/svnkit > /dev/null
if [ $? -ne 0 ]
then
  echo "Error adding ant. Aborting..."
  exit 1
fi

for repo in ${git_repo_list}
do
  repo_name_variable=${repo}_git_repo
  branch_variable=${repo}_branch_def
  dest_dir_variable=${repo}_dest_dir
  repo_name=${!repo_name_variable}
  repo_url=${git_url_root}/${repo_name}.git
  repo_dir=${git_clone_root}/${repo_name}
  branch_pattern=${!branch_variable}
  git_clone_dir=${git_clone_root}/${repo}

  echo Cloning Git repository ${repo_url} in ${repo_dir}...
  export GIT_WORK_TREE=${repo_dir}
  export GIT_DIR=${repo_dir}/.git
  git clone --no-checkout ${repo_url} ${GIT_DIR}
  if [ $? -ne 0 ]
  then
    echo "Error cloning Git repository ${repo_url}"
    exit 10
  fi

  # In fact branch can be a regexp matched against existing branch names
  branch_list=$(git branch -r | grep origin/${branch_pattern} | grep -v HEAD)
  for remote_branch in ${branch_list}
  do
    branch=$(echo ${remote_branch} | sed -e 's#^.*origin/##')
    dest_dir=${scdb_dir}/$(echo ${!dest_dir_variable} | sed -e "s#%BRANCH%#${branch}#")
    # os repository is a special case: '-spma' suffix must be removed to build the destination directory
    if [ ${repo} = "os" ]
    then
      dest_dir=$(echo ${dest_dir} | sed -e 's/-spma//')
    fi
    echo Copying Git branch ${branch} contents to ${dest_dir}...
    git checkout ${branch}
    mkdir -p ${dest_dir}
    cp -R ${repo_dir}/* ${dest_dir}
  done
done

echo "Compiling clusters/example..."
(cd ${scdb_dir}; external/ant/bin/ant --noconfig)