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
