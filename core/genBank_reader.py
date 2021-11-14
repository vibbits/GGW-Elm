from Bio import SeqIO
import json

# Object class for a vector:
class Vector:
    def __init__(self, name, mpg_number, sequence):
        self.name = name
        self.mpg_number = mpg_number
        self.sequence = sequence
        self.annotations = {}
        self.sequence_length = len(self.sequence)
        self.features = []

# Function that reads in a genbank file and converts it into a json
def convert_gbk_to_vector(genbank_file):
    try:
            # Reading the genbank file
        record = SeqIO.read(genbank_file, "genbank")

        # Create vector object:
        new_vector = Vector(
            name="".join(str(record.name).split('_')[1:]),
            mpg_number=str(record.name).split('_')[0],
            sequence=str(record.seq),
        )
        
        # Getting the annotations
        va_dict = {}
        for key, val in record.annotations.items():
            # All annotations are strings, integers or list of them but references are a special case.
            # References are objects that can be deconstructed to an author and a title, both strings.
            if key == "references":
                ref_list = {}
                for reference in record.annotations['references']:
                    ref_list['authors'] = reference.authors
                    ref_list['title'] = reference.title
                va_dict['references'] = ref_list
            else:
                va_dict[key] = val
        
        new_vector.annotations = va_dict

        # Getting the features:
        
        for feature in record.features:
            
            vf_dict = {}
            vf_dict['type']=feature.type
            vf_dict['qualifiers']=feature.qualifiers
            vf_dict['start_pos']=feature.location.nofuzzy_start
            vf_dict['end_pos']=feature.location.nofuzzy_end
            vf_dict['strand']=feature.location.strand
            new_vector.features.append(vf_dict)

        return new_vector            

    except :
        return "An error occurred trying to parse the genbankfile: '{}'.".format(genbank_file)       
# Remove me

