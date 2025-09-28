{lib, terraform, runCommand}:
runCommand "functions.json" {} ''
	${lib.getExe terraform} metadata functions -json > $out
''
