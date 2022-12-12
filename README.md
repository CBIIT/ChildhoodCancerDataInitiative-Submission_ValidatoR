# ChildhoodCancerDataInitiative-Submission_ValidatoR.R
This takes a CCDI Metadata template file as input and creates an output file basesd on the QC checks.

This R Script takes a data file that is formatted to the [submission template for CCDI](https://github.com/CBIIT/ccdi-model/tree/main/metadata-manifest) as input. It will output a file that describes whether sections of the Metadata table PASS, ERROR or WARNING on the checks.

To run the script on a CDS template, run the following command in a terminal where R is installed for help.

```
Rscript --vanilla CCDI-Submission_ValidatoR.R -h
```

```
Usage: CCDI-Submission_ValidatoR.R [options]

CCDI-Submission_ValidationR v1.0.0

Options:
	-f CHARACTER, --file=CHARACTER
		CCDI submission template workbook file (.xlsx, .tsv, .csv)

	-t CHARACTER, --template=CHARACTER
		CCDI dataset template file, can be the same Metadata template workbook file or a blank CCDI_submission_metadata_template.xlsx

	-h, --help
		Show this help message and exit
```

To test the script on one of the provided test files:

```
Rscript --vanilla CCDI-Submission_ValidatoR.R -f test_files/a_all_pass_CCDI_Submission_Template_v1.0.1.xlsx -t test_files/a_all_pass_CCDI_Submission_Template_v1.0.1.xlsx 
```

```
The data file is being validated at this time.

Process Complete.

The output file can be found here: ChildhoodCancerDataInitiative-Submission_ValidatoR.R/test_files/
```

`Note: The AWS bucket checks will not work with any of the test files, as the files and their locations are fake data`


|Message|Issue|Likely Fix|
|-------|-----|----------|
