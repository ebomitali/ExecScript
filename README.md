## ExecScript

Project for Gradle generic script execution phase for IKANALM

## ExecWinScript

  This module implements an IkanAlm phase based on a Gradle script.
  - almProperties.gradle setup context values, collect project properties, expands them using Ant filterchain
  - execWinScript.gradle defines a default task that will execute a bat/cmd command or a powershell file
  
The phase expect the script type (bat, cmd or powershell) in param.scriptType parameter and the command to execute in param.command parameter.
  The command is a string as you would write to the console. Parameters with spaces will be recognized if enclosed in quotes.
  Test directory set up a symulated IKANALM environment and then launch the gradle script.
  Tests will check both bat and powershell files containing a simple echo command

Test are available on windows nodes only.
To run test, cd into ExecWinScript/test directory and run "..\gradlew test"
To generate a zip file that could be loaded to IKANALM, run "..\gradlew pkgPhase". Zip file will be generate under build/dist directory
    

  