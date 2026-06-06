#raw data ingestion of Data API Breed's into GCP and Bigquery
import json
import requests
import pandas as pd
from datetime import datetime, timezone
from google.cloud import storage, biquery

#IDS
PROJECT_ID = "cogent-treat-409814" #project name at gcp
BUCKET_NAME = "heyra-dog-raw" #bucket of gcp
DATASET_ID = "bronze" #bigquery dataset
TABLE_ID = "dog_api_raw" #bigquery table name
API_URL = "https://api.thedogapi.com/v1/breeds" #API URL

def get_secret(secret_id):
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{PROJECT_ID}/secrets/{secret_id}/versions/latest"
    response = client.access_secret_version(request={"name": name})
    return response.payload.data.decode("UTF-8")

#defining the api function
def ingesting_api(request):
    #defining the calling date
    run_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    #api key 
    API_KEY = get_secret("dog-api-key")
    #calling API
    response = requests.get(API_URL, headers={"x-api-key": API_KEY}) #request the data from the API
    response.raise_for_status() #get status, to confirm if there is a timeout or error
    breeds= response.json() #gathers JSON data and add it to breeds
    print(f"{len(breeds)} rows found") #checking the lenght
    
    #saving json to bucket
    storage_client=storage.Client()
    bucket= storage_client.bucket(BUCKET_NAME)
    blob_path= f"breeds/run_date={run_date}/breeds"
    blob= bucket.blob(blob_path)
    blob.upload_from_string(
        json.dumps(breeds, indent=2),
        content_type="application/json"
    )
    print(f"Saved raw data to gs://{BUCKET_NAME}/{blob_path}")
    
    #adding to bronze schema
    bq_client = bigquery.Client()
    table_ref = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
        autodetect=True,
    )
    
    # breaking json by line
    ndjson = "\n".join([json.dumps(breed) for breed in breeds])

    job = bq_client.load_table_from_file(
        io.StringIO(ndjson),
        table_ref,
        job_config=job_config
    )
    job.result()
    
    print(f"Added {len(breeds)} rows into {table_ref}")
    return f"Pipeline ran successfully for {run_date}", 200



