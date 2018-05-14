#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: ExpressionTool
id: GATKConcordanceChecker
requirements:
  - class: InlineJavascriptRequirement

inputs:
 
  - id: summary
    type: File
    inputBinding:
      loadContents: true
      valueFrom: $(null)

  - id: threshold
    type: float

outputs:
  - id: flag
    type: boolean

expression: |
  ${
      var lines = inputs.summary.contents.split("\n");
      var flag = 1
      for (var i=1; i < lines.length; i++) {
          var sensitivity = lines[i].split("\t")[4];
          if (sensitivity < inputs.threshold) {
              flag = 0
          }
          var precision = parseFloat(lines[i].split("\t")[5]);
          if (precision < inputs.threshold) {
              flag = 0
          }
      }
      return {"flag": flag};
  }
