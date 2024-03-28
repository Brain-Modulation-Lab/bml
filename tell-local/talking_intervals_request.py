import os
import json
import argparse
import glob
import pandas as pd
import helper
import itertools

def parse_args():
    parser=argparse.ArgumentParser(description="This script calculates the talking intervals features of an audio wav file using the tell docker provided by Garcia Lab.")
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
        print(filename)
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
        csv_filename= os.path.join(output_path, "features_timing2.csv")        

        #articulation_features = json.loads(response["body"])["scores"]
        #print(response) 
        if "errorMessage" not in response: # save only if no errors
            talking_timing_scores = json.loads(response["body"])["scores"]
            #talking_timing_data= dict(itertools.islice(json.loads(response["body"])["data"].items(),2)) # slice only n_syllable and n_pauses
            talking_timing_data = dict(itertools.islice(json.loads(response["body"])["data"].items(),3)) # slice only n_syllable and n_pauses
            #talking_timing_data['__speech_segments'] = [talking_timing_data['__speech_segments']] # to list, to match with other outputs
    
            print(talking_timing_data)
            #convert dict to dataframe
            output = pd.DataFrame.from_dict({**talking_timing_data,**talking_timing_scores}, orient='index').transpose()
            output["session_id"] = session_id
            output["trial_id"] = trial_id
            output["audio_filename"] = filename
            
            
            output.to_csv(f"{csv_filename}", mode = 'a',index=False, header = not os.path.exists(csv_filename))


if __name__ == '__main__':
    main()