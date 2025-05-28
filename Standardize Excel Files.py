
import pandas as pd
import os
from glob import glob

# Drop data in raw data folder
folder = "raw_data/"
files = glob(os.path.join(folder, "*.xlsx"))

# Gather and combine all Excel files
merged_list = []

for f in files:
    sheet = pd.read_excel(f)
    # Standardize column names
    sheet.columns = sheet.columns.str.strip().str.lower().str.replace(" ", "_")
    merged_list.append(sheet)

# Combine all data into one
raw_merge = pd.concat(merged_list, ignore_index=True)

# Drop exact duplicates
raw_merge.drop_duplicates(inplace=True)

# Fill numeric missing values with 0
for col in raw_merge.select_dtypes(include='number').columns:
    raw_merge[col] = raw_merge[col].fillna(0)

# Drop rows missing a key identifier
if 'id' in raw_merge.columns:
    raw_merge.dropna(subset=['id'], inplace=True)

# Convert date columns
for col in raw_merge.columns:
    if 'date' in col:
        raw_merge[col] = pd.to_datetime(raw_merge[col], errors='coerce')

# Normalize text columns
for col in raw_merge.select_dtypes(include='object').columns:
    raw_merge[col] = raw_merge[col].astype(str).str.strip().str.lower()

# Remove outliers using IQR for numeric columns
#for column in raw_merge.select_dtypes(include='number').columns:
#    q1 = raw_merge[column].quantile(0.25)
#    q3 = raw_merge[column].quantile(0.75)
#    iqr = q3 - q1
#    lower_bound = q1 - 1.5 * iqr
#    upper_bound = q3 + 1.5 * iqr
#    raw_merge = raw_merge[(raw_merge[column] >= lower_bound) & (raw_merge[column] <= upper_bound)]

# Save cleaned data
output_file = "cleaned_data.xlsx"
raw_merge.to_excel(output_file, index=False)

print(f"Cleaned file saved as: {output_file}")
