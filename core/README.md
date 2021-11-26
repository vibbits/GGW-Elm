# Core application of GGW-ELM

## Layout of a genbank record:
**Resources:** [Biopython - SeqRecord]("https://biopython.org/docs/1.75/api/Bio.SeqRecord.html?highlight=seqrecord#module-Bio.SeqRecord")
* seq
* id
* name
* description
* dbxrefs
* features = SeqFeature Object
    * qualifier = OrderedDict
        * All qualifiers are strings, integers or lists of strings or integers.
    * positions (begin, end, strand)
    * type
* annotations = OrderedDict
    * All annotations are strings, integers or lists of strings or integers.
    * Except for references => Reference Objects
        * title: String
        * authors: String

## Reading Genbank files and parsing them to JSON

**Resources:** [Biopython - SeqIO.read]("https://biopython.org/docs/1.75/api/Bio.SeqIO.html?highlight=seqio%20write#Bio.SeqIO.read")

This module will serve as purpose to read in genbank files and converting them in something that is easily convertible like a JSON file.

### Class object takes in the following parameters:
* Name
* MPG number
* Sequence
* A list of annotations
* A list of features

```python
class Vector:
    def __init__(self, name, mpg_number, sequence):
        self.name = name
        self.mpg_number = mpg_number
        self.sequence = sequence
        self.annotations = {}
        self.sequence_length = len(self.sequence)
        self.features = []
```




## Writing Genbank files starting from JSON files
Genbank files can be written by first converting the json files to Records and then writing the information to a Genbank file.
**Resources**: [Biopython - SeqIO.write](https://biopython.org/docs/1.75/api/Bio.SeqIO.html?highlight=seqio%20write#Bio.SeqIO.write)
