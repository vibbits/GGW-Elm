# Core application of GGW-ELM

## Reading Genbank files and parsing them to JSON

**Resources:** [Biopython]("https://biopython.org/docs/1.75/api/index.html")

This module will serve as purpose to read in genbank files and converting them in something that is easily convertible like a JSON file.

### Class object takes in the following parameters:
* Name
* MPG number
* Sequence
* A list of annotations
* A list of features

```python
class Vector:
    def __init__(self, name, mpg_number, sequence, annotations):
        self.name = name
        self.mpg_number = mpg_number
        self.sequence = sequence
        self.annotations = annotations
        self.sequence_length = len(self.sequence)
        self.features = []
```