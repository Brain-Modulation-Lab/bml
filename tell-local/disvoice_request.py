import os
import json
import argparse
import glob
import pandas as pd
import helper


def parse_args():
    parser=argparse.ArgumentParser(description="This script calculates the articulatory features of an audio wav file using the tell docker provided by Garcia Lab.")
    parser.add_argument("--input", help = "audio filepath")
    parser.add_argument("--output", help = "output folder")
    args=parser.parse_args()

    print("the inputs are:")
    for arg in vars(args):
        print("{} is {}".format(arg, getattr(args, arg)))
    return args


def main():
    # this is the main
    # parse input
    params=parse_args()
    input_path = params.input
    output_path = params.output

    # get url
    url = helper.retrieve_url()
    # conver audio file to base64
    for filename in glob.glob(os.path.join(input_path, '*.wav')):
        encoded_file_content = helper.encode_file_to_base64(filename)
        data = {
            "audio_file":
            {"file": encoded_file_content}
            }
       
        session_id, trial_id = helper.get_identifier(filename)
        response = helper.call_api(url, data)
        
        # use os to re-define output_path
        base_name = os.path.basename(input_path)  # Get the base filename from the path
        name_without_extension = os.path.splitext(base_name)[0]  # Remove the extension
        csv_filename= os.path.join(output_path, "features_articulation.csv")        
        
        
        print(response)
        
        if "errorMessage" not in response: # save only if no errors
        
            articulation_features = json.loads(response["body"])["data"]["articulation_features"]
            phonological_features = json.loads(response["body"])["data"]["phonological_features"]
            #convert dict to dataframe
            output = pd.DataFrame.from_dict({**articulation_features,**phonological_features}, orient='index').transpose()
            output["session_id"] = session_id
            output["trial_id"] = trial_id
            output["audio_filename"] = filename
            
            
            output.to_csv(f"{csv_filename}", mode = 'a',index=False, header = not os.path.exists(csv_filename))


if __name__ == '__main__':
    main()