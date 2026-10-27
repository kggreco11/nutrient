#!/usr/bin/env python3
"""Rebuild the bundled USDA SR Legacy database from the official public download.
Usage: python3 scripts/import-usda.py [/path/to/download.zip]
Missing nutrients remain null. All nutrition values are per 100 grams.
"""
import csv, io, json, sys, urllib.request, zipfile, hashlib
from pathlib import Path
URL='https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip'
raw=Path(sys.argv[1]).read_bytes() if len(sys.argv)>1 else urllib.request.urlopen(URL).read()
z=zipfile.ZipFile(io.BytesIO(raw)); root=z.namelist()[0]
def rows(name): return csv.DictReader(io.TextIOWrapper(z.open(root+name+'.csv')))
keys={'protein':1003,'carbs':1005,'fat':1004,'fiber':1079,'vitA':1106,'vitC':1162,'vitD':1114,'vitE':1109,'vitK':1185,'b1':1165,'b2':1166,'b6':1175,'b12':1178,'folate':1190,'calcium':1087,'iron':1089,'magnesium':1090,'potassium':1092,'zinc':1095,'selenium':1103}
needed=set(keys.values())|{1008,1404,1272,1278,1280}
values={}
for row in rows('food_nutrient'):
 nid=int(row['nutrient_id'])
 if nid in needed: values.setdefault(row['fdc_id'],{})[nid]=float(row['amount'])
result=[]
for f in rows('food'):
 v=values.get(f['fdc_id'],{})
 if 1008 not in v: continue
 n={key:v.get(nid) for key,nid in keys.items()}
 # Report combined omega-3 only when all four explicit n-3 components exist.
 omega=[v.get(i) for i in [1404,1272,1278,1280]]
 n['omega3']=round(sum(omega),6) if all(x is not None for x in omega) else None
 result.append({'id':'usda-'+f['fdc_id'],'name':f['description'],'serving':'100 g','emoji':'◈','calories':v[1008],'values':n,'kind':'food','source':'USDA SR Legacy','sourceId':f['fdc_id'],'restaurant':f['food_category_id']=='21'})
result.sort(key=lambda f:f['name'].lower())
out=Path(__file__).resolve().parents[1]/'public/data';out.mkdir(parents=True,exist_ok=True)
(out/'usda-sr-legacy.json').write_text(json.dumps(result,separators=(',',':')))
(out/'usda-manifest.json').write_text(json.dumps({'source':'USDA FoodData Central / SR Legacy','release':'April 2018 (final SR release)','publicationDate':'2019-04-01','downloadUrl':URL,'sourceSha256':hashlib.sha256(raw).hexdigest(),'foodCount':len(result),'restaurantCount':sum(f['restaurant'] for f in result),'basis':'per 100 g','license':'Public domain / CC0','micronutrients':'Vitamin A as RAE; folate as DFE; vitamin D in micrograms; omega-3 only when all ALA/EPA/DHA/DPA components are reported'},indent=2)+'\n')
print(f'Imported {len(result)} foods, including {sum(f["restaurant"] for f in result)} historical fast-food entries.')
