PACKAGE_JSON_LIST=()
DIRS=()
DIRTYDIRS=()


DEFAULT_START_BRANCH="master"
DEFAULT_DESTINATION_BRANCH="feature-test"
DEFAULT_MESSAGE="package.json"
DEFAULT_EDITOR="gvim -fp"
DEFAULT_DEVREPOS_FILE="devrepos"
DEFAULT_EXCLUDEREPOS_FILE="excluderepos"
PREFIX="../release-helper"
DIRS_PREFIX=".."


prepareGit() {
    git reset
    echo "Stashing:                    #" git stash -u
    git stash -u
    echo "Fetching:                    #" git fetch
    git fetch
}


editPackageJson() {
    echo "Editing package.json:         #" node "$PREFIX/editPackage.js package.json $DESTINATION_BRANCH $PREFIX/$DEVREPOS_FILE $PREFIX/$EXCLUDEREPOS_FILE"
    node $PREFIX/editPackage.js package.json $DESTINATION_BRANCH $PREFIX/$DEVREPOS_FILE $PREFIX/$EXCLUDEREPOS_FILE
    echo "Adding to stage:              #" git add -u
    git add -u
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


commitDirectory() {
    echo "$PWD: "
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
        read -p "Enter start branch ($DEFAULT_START_BRANCH):" START_BRANCH
        START_BRANCH=${START_BRANCH:-$DEFAULT_START_BRANCH}
    else
        START_BRANCH=$1
    fi

    if [ -z "$2" ];
    then
        read -p "Enter destination branch:" DESTINATION_BRANCH
        DESTINATION_BRANCH=${DESTINATION_BRANCH:-$DEFAULT_DESTINATION_BRANCH}
    else
        DESTINATION_BRANCH=$2
    fi

    if [ -z "$3" ];
    then
        read -p "Enter editor command. Note, should wait ($DEFAULT_EDITOR):" EDITOR
        EDITOR=${EDITOR:-$DEFAULT_EDITOR}
    else
        DESTINATION_BRANCH=$3
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
}

setupDirs() {
    for d in `find $DIRS_PREFIX/ -name .git -type d -not -path "$PWD" -prune`
    do
        DIRS+=("$d/..")
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

main() {
    for d in "${DIRS[@]}"
    do
       cd $d
       processDirectory
       cd $OLDPWD
    done

    echo "Opening package.json"
    `$EDITOR ${PACKAGE_JSON_LIST[*]}`

    echo "Commiting dirty dirs"
    commitDirtyDirs

    echo "Pushing dirty dirs"
    pushDirtyDirs
}

setupEnvironment $1 $2 $3

setupDirs

main

echo "DONE"
