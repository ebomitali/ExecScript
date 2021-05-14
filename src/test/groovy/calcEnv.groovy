def reduceEnvName(String name) {
    switch (name) {
        case ~/^PREPROR.*$/:
            envName = 'PREPRO'
            break
        case ~/^PRODR.*$/:
            envName = 'PROD'
            break
        default:
            envName = name
            break
    }
    envName
}

assert reduceEnvName('INTR1') == 'INTR1'
assert reduceEnvName('INTR2') == 'INTR2'
assert reduceEnvName('SYSR2') == 'SYSR2'
assert reduceEnvName('PREPROR1') == 'PREPRO'
assert reduceEnvName('PREPROR2') == 'PREPRO'
assert reduceEnvName('PREPRORLSE') == 'PREPRO'
assert reduceEnvName('PRODR1') == 'PROD'
assert reduceEnvName('PRODR2') == 'PROD'
assert reduceEnvName('PRODRLSE') == 'PROD'