package it.zebco.ikan.alm.phase.execcmd

import org.apache.commons.io.FileUtils
import org.gradle.testkit.runner.GradleRunner
import org.gradle.testkit.runner.TaskOutcome
import org.junit.Rule
import org.junit.rules.TemporaryFolder
import spock.lang.Ignore
import spock.lang.Requires
import spock.lang.Shared
import spock.lang.Specification
import org.gradle.internal.os.OperatingSystem

@Requires({ OperatingSystem.current().isWindows() })
class execCmdSpec extends Specification {
    // creates temperary folder automatically cleaned up on exit
    @Rule public final TemporaryFolder testProjectDir = new TemporaryFolder(new File('D:/Temp'));
    @Shared File phaseDir, artifactDir, sourceDir, testGradleProps

    // reference the build file where dependencies defined
    // every setup gets a different temporary directory
    def setup() {
        //println "Tempdir is ${testProjectDir.getRoot().canonicalPath}"
        // ikan context
        File dirIkan = testProjectDir.newFolder('ikan')
        File dirAlm = testProjectDir.newFolder('ikan', 'alm')
        File projResourcesDir = testProjectDir.newFolder('ikan', 'system', 'projectResources')
        FileUtils.copyFileToDirectory(new File('src/test/resources/EXECCMD.properties'), projResourcesDir )

        // ikan source directory
        sourceDir = testProjectDir.newFolder('source', '123456')
        FileUtils.copyFileToDirectory(new File('src/test/resources/TEST-COR-XYZ.properties'), sourceDir)
        //artifactDir = testProjectDir.newFolder('source', '123456', 'artifact') // used in test
        File targetDir = testProjectDir.newFolder('target') // not used
        File targetPackageOidDir = testProjectDir.newFolder('target', '13235') //should match alm.package.oid in gradle.properties

        // phase directory and content
        phaseDir = testProjectDir.newFolder('source', '123456', 'it.test.phase')
        //File libDir = testProjectDir.newFolder('source', '123456', 'it.test.phase', 'lib')
        //FileUtils.copyDirectory(new File('src/main/lib'), libDir)
        FileFilter gradleFilter = new FileFilter() {
            @Override
            public boolean accept(File filename) {
                filename.getName().toLowerCase().endsWith(".gradle");
            }
        }
        FileUtils.copyDirectory(new File('src/main'), phaseDir, gradleFilter)
        FileUtils.copyFileToDirectory(new File('src/test/resources/gradle.properties'), phaseDir) // pkg deploy gradle props
        testGradleProps = new File(phaseDir, 'gradle.properties')
        // add some properties, should convert to java path format using / instead of \
        testGradleProps << "dir.ikan.home=${dirIkan.canonicalPath.replace('\\', '/')}\n"
        testGradleProps << "source=${sourceDir.canonicalPath.replace('\\', '/')}\n"
        testGradleProps << "target=${targetDir.canonicalPath.replace('\\', '/')}\n"
        //do we need settings.gradle ?
    }

    def cleanup() {
        //unable to debug, copy files and context to be reviewed
        FileUtils.copyDirectory(testProjectDir.root, new File('D:/Temp/GradleTest/execCmd'))
        println "cleanup"
    }

    def "exec a simple cmd with arguments" () {
        setup:
        // copy ear to artifact directory
        FileUtils.copyFileToDirectory(new File('src/test/resources/echoArgs.bat'), sourceDir)
        testGradleProps << "param.command=echoArgs.bat prova1 prova2 prova3 prova4\n"
        when:
        def result = GradleRunner.create()
                .withProjectDir(phaseDir)
                .withArguments(['-b', 'execWinScript.gradle', 'execBat'])
                .build()
        // extract temporary directory
        println "Execution output ${result.output}"

        then:
        //result.task('simulateExecRjDeploy').outcome == TaskOutcome.SUCCESS
        result.task(":execBat").outcome == TaskOutcome.SUCCESS
        result.output.contains('prova1 prova2 prova3 prova4')
    }

    def "Execute a simple ps1 file with arguments in sourceDir" () {
        setup:
        // copy ear to artifact directory
        FileUtils.copyFileToDirectory(new File('src/test/resources/write-host.ps1'), sourceDir)
        testGradleProps << "param.command=write-host.ps1 prova1 prova2 prova3 prova4\n"
        when:
        def result = GradleRunner.create()
                .withProjectDir(phaseDir)
                .withArguments(['-b', 'execWinScript.gradle', 'execPowershell'])
                .build()
        // extract temporary directory
        println "Execution output ${result.output}"

        then:
        result.task(":execPowershell").outcome == TaskOutcome.SUCCESS
        result.output.contains('prova1 prova2 prova3 prova4')
    }

    def "Execute a simple ps1 file with arguments in an absolute directory" () {
        setup:
        File dirPowershell = testProjectDir.newFolder('powershell')
        FileUtils.copyFileToDirectory(new File('src/test/resources/write-host.ps1'), dirPowershell)
        testGradleProps << "param.command=${dirPowershell.canonicalPath.replace('\\', '/')}/write-host.ps1 prova4 prova3 prova2 prova1\n"
        when:
        def result = GradleRunner.create()
                .withProjectDir(phaseDir)
                .withArguments(['-b', 'execWinScript.gradle', 'execPowershell'])
                .build()
        // extract temporary directory
        println "Execution output ${result.output}"

        then:
        result.task(":execPowershell").outcome == TaskOutcome.SUCCESS
        result.output.contains('prova4 prova3 prova2 prova1')
    }

    def "exec a simple bat in execWinScript task" () {
        setup:
        // copy ear to artifact directory
        FileUtils.copyFileToDirectory(new File('src/test/resources/echoArgs.bat'), sourceDir)
        testGradleProps << "param.scriptType=bat\n"
        testGradleProps << "param.command=echoArgs.bat prova1 prova2 prova3 prova4\n"
        when:
        def result = GradleRunner.create()
                .withProjectDir(phaseDir)
                .withArguments(['-b', 'execWinScript.gradle', 'execWinScript'])
                .build()
        // extract temporary directory
        println "Execution output ${result.output}"

        then:
        //result.task('simulateExecRjDeploy').outcome == TaskOutcome.SUCCESS
        result.task(":execWinScript").outcome == TaskOutcome.SUCCESS
        result.output.contains('prova1 prova2 prova3 prova4')
    }

    def "Execute a simple ps1 in execWinScript task" () {
        setup:
        File dirPowershell = testProjectDir.newFolder('powershell')
        FileUtils.copyFileToDirectory(new File('src/test/resources/write-host.ps1'), sourceDir)
        testGradleProps << "param.scriptType=powershell\n"
        testGradleProps << "param.command=write-host.ps1 prova4 prova3 prova2 prova1\n"
        when:
        def result = GradleRunner.create()
                .withProjectDir(phaseDir)
                .withArguments(['-b', 'execWinScript.gradle', 'execWinScript'])
                .build()
        // extract temporary directory
        println "Execution output ${result.output}"

        then:
        result.task(":execWinScript").outcome == TaskOutcome.SUCCESS
        result.output.contains('prova4 prova3 prova2 prova1')
    }

    def "Execute ps1 script with windows path in execWinScript task" () {
        setup:
        File dirPowershell = testProjectDir.newFolder('powershell')
        FileUtils.copyFileToDirectory(new File('src/test/resources/write-host.ps1'), dirPowershell)
        testGradleProps << "param.scriptType=powershell\n"
        testGradleProps << "param.command=${dirPowershell.canonicalPath.replace('\\', '/')}/write-host.ps1 prova4 prova3 prova2 prova1\n"
        when:
        def result = GradleRunner.create()
                .withProjectDir(phaseDir)
                .withArguments(['-b', 'execWinScript.gradle'])
                .build()
        // extract temporary directory
        println "Execution output ${result.output}"

        then:
        result.task(":execWinScript").outcome == TaskOutcome.SUCCESS
        result.output.contains('prova4 prova3 prova2 prova1')
    }
}
