#!/bin/bash
if [[ $1 != '--functional' && $1 != '--integration' ]]; then
    echo "Unknow test"
    exit
fi


TRAVIS_BUILD_DIR=$PWD
pip install -r requirements.txt

if [ ! -d tests ]; then
    mkdir tests
fi
cd tests


# Install tool dependencies
# =========================
export INSTALL_DIR=/tmp/dep_install
if [ -d $INSTALL_DIR ]; then
    if [[ -z $2 ]]; then
        rm -rf $INSTALL_DIR
        mkdir $INSTALL_DIR
    elif [[ $2 != '--no-reset' ]]; then
        rm -rf $INSTALL_DIR
        mkdir $INSTALL_DIR
    fi
else
    mkdir $INSTALL_DIR
fi


export DOWNLOAD_CACHE=/tmp/download_cache
if [ -d $DOWNLOAD_CACHE ]; then
    if [[ -z $2 ]]; then
        rm -rf $DOWNLOAD_CACHE
        mkdir $DOWNLOAD_CACHE
    elif [[ $2 != '--no-reset' ]]; then
        rm -rf $DOWNLOAD_CACHE
        mkdir $DOWNLOAD_CACHE
    fi
else
    mkdir $DOWNLOAD_CACHE
fi

for i in $( ls ${TRAVIS_BUILD_DIR}/packages/ )
do 
    planemo dependency_script ${TRAVIS_BUILD_DIR}/packages/$i/
    bash dep_install.sh
    source env.sh
done

for i in $( ls ${TRAVIS_BUILD_DIR}/tools/ )
do 
    planemo dependency_script ${TRAVIS_BUILD_DIR}/tools/$i/
    bash dep_install.sh
    source env.sh
done

# Install Galaxy
# ==============
function install_galaxy {
    wget https://codeload.github.com/galaxyproject/galaxy/tar.gz/master
    tar -zxvf master | tail
    rm master
}

if [ -d "galaxy-master" ]; then
    if [[ -z $2 ]]; then
        rm -rf galaxy-master
        install_galaxy
    elif [[ $2 != '--no-reset' ]]; then
        rm -rf galaxy-master
        install_galaxy
    fi
else
    install_galaxy
fi
cd galaxy-master

# Configure tools in Galaxy
# =========================
function create_symlink {
    if [ -e $1 ]; then
        if [ ! -L $1 ]; then
            rm -rf $1
            ln -s $2 $1
        fi
    else
        ln -s $2 $1
    fi 
}

export GALAXY_TEST_UPLOAD_ASYNC=false
export GALAXY_TEST_DB_TEMPLATE=https://github.com/jmchilton/galaxy-downloads/raw/master/db_gx_rev_0127.sqlite

rm -f tool_conf.xml
ln -s ${TRAVIS_BUILD_DIR}/.travis.tool_conf.xml $PWD/tool_conf.xml
rm -f config/tool_conf.xml.sample
ln -s ${TRAVIS_BUILD_DIR}/.travis.tool_conf.xml $PWD/config/tool_conf.xml.sample
rm -f config/shed_tool_data_table_conf.xml
ln -s ${TRAVIS_BUILD_DIR}/.travis.tool_data_table_conf.xml $PWD/config/shed_tool_data_table_conf.xml

for i in $( ls ${TRAVIS_BUILD_DIR}/tools/ )
do 
    create_symlink $PWD/tools/$i ${TRAVIS_BUILD_DIR}/tools/$i/
    for j in $( ls ${TRAVIS_BUILD_DIR}/tools/$i/test-data/ )
    do
        create_symlink $PWD/test-data/$j ${TRAVIS_BUILD_DIR}/tools/$i/test-data/$j
    done
    if [ -d ${TRAVIS_BUILD_DIR}/tools/$i/tool-data/ ]; then
        for j in $( ls ${TRAVIS_BUILD_DIR}/tools/$i/tool-data/ )
        do
            create_symlink $PWD/tool-data/$j ${TRAVIS_BUILD_DIR}/tools/$i/tool-data/$j
        done
    fi
done


if [ $1 == '--functional' ]; then
    ./run.sh --stop-daemon || true
    python scripts/fetch_eggs.py

    # Test tools
    # ==========
    python ./scripts/functional_tests.py -v `python tool_list.py Continuous-Integration-Travis`
elif [ $1 == '--integration' ]; then
    ./run.sh
else
    echo "Unknow test"
fi