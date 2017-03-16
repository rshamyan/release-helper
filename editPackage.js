"use strict"

const path = require('path');
const fs = require('fs');

const args = process.argv.slice(2);
const packageJson = require(path.resolve(process.cwd(), args[0]));
const destinationBranch = args[1];
const devRepos = fs.readFileSync(args[2]).toString().split('\n');
const excludeRepos = fs.readFileSync(args[3]).toString().split('\n');
const commitsfile = fs.readFileSync(args[4]).toString().split('\n')
    .map(s => {
        let m = s.split('#');
        return {
            repo: m[0],
            hash: m[1]
        };
    });

function edit(obj) {
    Object.keys(obj).forEach(key => {
        let value = obj[key];
        let m = /^git\+ssh:\/\/(.+)#(.+)$/.exec(value);
        let isGitRepo = !!m && !!m[0];
        let isRelease = destinationBranch.startsWith('release');
        let isHotfix = destinationBranch.startsWith('hotfix');
        if (isGitRepo) {
            let newValue = value;
            let repo = m[1];
            let isDevRepo = devRepos.find(r => r == repo);
            let isExcludeRepo = excludeRepos.find(r => r == repo);
            let foundInCommitsFile = commitsfile.find(r => r.repo == repo);
            let hash;
            if (isDevRepo) {
                if (isHotfix) {
                    console.log(`>>> Package.json: Hotfix: Ignoring "${key}":"${newValue}"`)
                } else {
                    if (foundInCommitsFile) {
                        hash = foundInCommitsFile.hash
                    } else {
                        hash = isRelease ? destinationBranch : 'dev';
                    }
                    newValue = `git+ssh://${repo}#${hash}`
                }
            } else if (!isExcludeRepo) {
                // TODO disable project repo commit hash freezing
                // if (foundInCommitsFile) {
                //     hash = foundInCommitsFile.hash;
                // } else {
                    hash = destinationBranch;
                // }
                newValue = `git+ssh://${repo}#${hash}`
            }
            console.log(`>>> Package.json: Setting "${key}":"${newValue}"`)
            obj[key] = newValue;
        }
    });
}

packageJson.dependencies && edit(packageJson.dependencies);
packageJson.devDependencies && edit(packageJson.devDependencies);

fs.writeFileSync(args[0], JSON.stringify(packageJson, null, 2) + '\n');
