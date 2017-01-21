PACKAGE_JSON_LIST=()
DIRS=()
DIRTYDIRS=()


DEFAULT_START_BRANCH="master"
DEFAULT_DESTINATION_BRANCH="feature-test"
DEFAULT_MESSAGE="package.json"
DEFAULT_EDITOR="gvim -fp"
DEFAULT_DEVREPOS_FILE="devrepos"
DEFAULT_EXCLUDEREPOS_FILE="excluderepos"
DEFAULT_COMMITS_FILE="commitsfile"
DEFAULT_MODE="create-branch"
PREFIX="../release-helper"
DIRS_PREFIX=".."

#set -e


prepareGit() {
    git reset
    echo "Stashing:                    #" git stash -u
    git stash -u
    echo "Fetching:                    #" git fetch
    git fetch
}


editPackageJson() {
    echo "Editing package.json:         #" node "$PREFIX/editPackage.js package.json $DESTINATION_BRANCH $PREFIX/$DEVREPOS_FILE $PREFIX/$EXCLUDEREPOS_FILE"
    node $PREFIX/editPackage.js package.json $DESTINATION_BRANCH $PREFIX/$DEVREPOS_FILE $PREFIX/$EXCLUDEREPOS_FILE $PREFIX/$COMMITS_FILE
}


createBranch() {
    echo "Checkout to start:           #" git checkout $START_BRANCH
    git checkout $START_BRANCH
    echo "Pulling to start:            #" git pull origin $START_BRANCH
    git pull origin $START_BRANCH
    echo "Creating destination branch: #" git checkout -b $DESTINATION_BRANCH
    git checkout $DESTINATION_BRANCH || git checkout -b $DESTINATION_BRANCH
}


processProjectDirectory() {
    echo "Processing project repo"

    prepareGit

    createBranch

    editPackageJson
}

processDevDirectory() {
    echo "Processing dev repo"

    prepareGit

    if (echo "$DESTINATION_BRANCH" | grep -Eq ^release)
    then
        createBranch

    else
        echo "Checkout to dev:             #" git checkout dev
        git checkout dev

        echo "Pulling to dev:              #" git pull origin dev
        git pull origin dev

    fi

    editPackageJson
}

processDirectory() {
    echo "$PWD:"
    echo "Detecting repo                  #" git config --get remote.origin.url
    local repo=`git config --get remote.origin.url`
    echo $repo
    if grep -Eq "^$repo" "$PREFIX/$DEVREPOS_FILE";
    then
        processDevDirectory
        DIRTYDIRS+=($PWD)
    else
        if grep -Eq "^$repo" "$PREFIX/$EXCLUDEREPOS_FILE";
        then
            echo "Ignoring this repo"
        else
            processProjectDirectory
            DIRTYDIRS+=($PWD)
        fi
    fi
    PACKAGE_JSON_LIST+=("$PWD/package.json")
}

pushToCommitsFile() {
    local hash=`git log -1 --format="%H"`
    local repo=`git config --get remote.origin.url`
    local repo2=$repo
    repo2=`echo ${repo2/\:/\/}`
    echo "Pushing to commits file $repo#$hash"
    echo "$repo#$hash" >> "$PREFIX/$COMMITS_FILE"
    echo "Pushing to commits file $repo2#$hash"
    echo "$repo2#$hash" >> "$PREFIX/$COMMITS_FILE"
}


freezeProjectDirectory() {
    echo "Freezing project repo"

    prepareGit

    echo "Checkout to $DESTINATION_BRANCH:#" git checkout $DESTINATION_BRANCH
    git checkout $DESTINATION_BRANCH

    echo "Pulling to $DESTINATION_BRANCH: #" git pull origin $DESTINATION_BRANCH
    git pull origin $DESTINATION_BRANCH

    pushToCommitsFile
}

freezeDevDirectory() {
    echo "Freezing dev repo"

    prepareGit

    echo "Checkout to dev:             #" git checkout dev
    git checkout dev

    echo "Pulling to dev:              #" git pull origin dev
    git pull origin dev

    pushToCommitsFile
}

freezeDirectory() {
    echo "$PWD:"
    echo "Detecting repo                  #" git config --get remote.origin.url
    local repo=`git config --get remote.origin.url`
    echo $repo
    if grep -Eq "^$repo" "$PREFIX/$DEVREPOS_FILE";
    then
        freezeDevDirectory
        DIRTYDIRS+=($PWD)
    else
        if grep -Eq "^$repo" "$PREFIX/$EXCLUDEREPOS_FILE";
        then
            echo "Ignoring this repo"
        else
            freezeProjectDirectory
            DIRTYDIRS+=($PWD)
        fi
    fi
    PACKAGE_JSON_LIST+=("$PWD/package.json")
}

commitDirectory() {
    echo "$PWD: "
    echo "Adding to stage              #" git add -u
    git add -u
    echo "Commiting:                   #" git commit -m "$COMMIT_MESSAGE"
    git commit -m "$COMMIT_MESSAGE"
}


pushToServer() {
    echo "$PWD: "
    local BRANCH
    local repo=`git config --get remote.origin.url`
    if grep -Eq "^$repo" "$PREFIX/$DEVREPOS_FILE";
    then
        if (echo "$DESTINATION_BRANCH" | grep -Eq ^release)
        then
            BRANCH=$DESTINATION_BRANCH
        else
            BRANCH="dev"
        fi
    else
        BRANCH=$DESTINATION_BRANCH
    fi
    echo "Pushing to origin            #" git push -u origin $BRANCH
    git push -u origin $BRANCH
}

setupEnvironment() {
    if [ -z "$1" ];
    then
        read -p "Enter mode ($DEFAULT_MODE):" MODE
        MODE=${MODE:-$DEFAULT_MODE}
    else
        MODE=$1
    fi
    if [ -z "$2" ];
    then
        read -p "Enter start branch ($DEFAULT_START_BRANCH):" START_BRANCH
        START_BRANCH=${START_BRANCH:-$DEFAULT_START_BRANCH}
    else
        START_BRANCH=$2
    fi

    if [ -z "$3" ];
    then
        read -p "Enter destination branch:" DESTINATION_BRANCH
        DESTINATION_BRANCH=${DESTINATION_BRANCH:-$DEFAULT_DESTINATION_BRANCH}
    else
        DESTINATION_BRANCH=$3
    fi

    if [ -z "$4" ];
    then
        read -p "Enter editor command. Note, should wait ($DEFAULT_EDITOR):" EDITOR
        EDITOR=${EDITOR:-$DEFAULT_EDITOR}
    else
        DESTINATION_BRANCH=$4
    fi

    read -p "Enter dev repos file ($DEFAULT_DEVREPOS_FILE): " DEVREPOS_FILE
    DEVREPOS_FILE=${DEVREPOS_FILE:-$DEFAULT_DEVREPOS_FILE}
    if ! [ -f $DEVREPOS_FILE ];
    then
        echo "file $DEVREPOS_FILE not found"
        exit
    fi

    read -p "Enter exclude repos file ($DEFAULT_EXCLUDEREPOS_FILE): " EXCLUDEREPOS_FILE
    EXCLUDEREPOS_FILE=${EXCLUDEREPOS_FILE:-$DEFAULT_EXCLUDEREPOS_FILE}
    if ! [ -f $EXCLUDEREPOS_FILE ];
    then
        echo "file $EXCLUDEREPOS_FILE not found"
        exit
    fi

    read -p "Enter commits file ($DEFAULT_COMMITS_FILE): " COMMITS_FILE
    COMMITS_FILE=${COMMITS_FILE:-$DEFAULT_COMMITS_FILE}
    if [ -f $COMMITS_FILE ]
    then
        echo "Cleaning $COMMITS_FILE"
        rm -rf $COMMITS_FILE
    fi
    touch $COMMITS_FILE
}

setupDirs() {
    for d in `find $DIRS_PREFIX/ -name .git -type d -prune`
    do
        local REALPATH=`realpath $d/..`
        if [ "$REALPATH" = "$PWD" ]
        then
            echo "Skiping $REALPATH"
        else
            DIRS+=("$d/..")
        fi
    done
}


commitDirtyDirs() {
    read -p "Enter commit message ($DEFAULT_MESSAGE):" COMMIT_MESSAGE
    COMMIT_MESSAGE=${COMMIT_MESSAGE:-$DEFAULT_MESSAGE}
    for d in "${DIRTYDIRS[@]}"
    do
        cd $d
        commitDirectory
        cd $OLDPWD
    done
}

pushDirtyDirs() {
    read -p "Push to Server? (y/n):" BOOL
    if [ "$BOOL" = "y" ];
    then
        for d in "${DIRTYDIRS[@]}"
        do
            cd $d
            pushToServer
            cd $OLDPWD
        done
    fi
}

createBranchMode() {
    for d in "${DIRS[@]}"
    do
       cd $d
       processDirectory
       cd $OLDPWD
    done

    echo "Opening package.json"
    $EDITOR ${PACKAGE_JSON_LIST[*]}

    echo "Commiting dirty dirs"
    commitDirtyDirs

    echo "Pushing dirty dirs"
    pushDirtyDirs
}

freezeBranchMode() {
    for d in "${DIRS[@]}"
    do
       cd $d
       freezeDirectory
       cd $OLDPWD
    done
    for d in "${DIRTYDIRS[@]}"
    do
        cd $d
        editPackageJson
        cd $OLDPWD
    done

    echo "Opening package.json"
    $EDITOR ${PACKAGE_JSON_LIST[*]}

    echo "Commiting dirty dirs"
    commitDirtyDirs

    echo "Pushing dirty dirs"
    pushDirtyDirs
}

runInMode() {
    case $MODE in
        "create-branch"|"unfreeze-branch")
            createBranchMode
            ;;
        "freeze-branch")
            freezeBranchMode
            ;;
        "*")
            echo "Unknown mode $MODE"
            exit 1
    esac
}

setupEnvironment $1 $2 $3 $4

setupDirs

runInMode

echo "DONE"
