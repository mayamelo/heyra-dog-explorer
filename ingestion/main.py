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

#defining the api function
def ingesting_api(request):
    #defining the calling date
    run_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    #calling API
    response = request.
    


