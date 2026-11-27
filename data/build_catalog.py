import pandas as pd,re,json,urllib.parse
SRC='Galti_inventory_with_images.xlsx'
df=pd.read_excel(SRC,sheet_name='Products',dtype=str)
# ---- departments and aisles (cat id -> aisle). First 34 ids come from the brief, the rest inferred from product names.
D=[('beverages','Beverages & Hot Drinks'),('snacks','Snacks, Biscuits & Confectionery'),('pantry','Pantry, Cooking & Staples'),('fresh','Dairy, Bakery, Meat & Frozen'),('care','Personal Care, Health & Pharmacy'),('household','Household & Cleaning'),('home','Home, Kitchen & Hardware'),('school','Stationery, Toys & School'),('tech','Electronics & Accessories')]
DI={d[0]:i for i,d in enumerate(D)}
M=[ # (cat id, aisle label, dept)
('69622eacd3cb441f5303cc32','Juices, Water & Soft Drinks','beverages'),('69622e7dd3cb441f5303ba15','Tea, Coffee & Energy Drinks','beverages'),
('69622f01d3cb441f53040d87','Cakes, Crisps & Snacks','snacks'),('69622e84d3cb441f5303bb62','Biscuits & Cookies','snacks'),('69622f12d3cb441f53042514','Sweets, Lollipops & Candy','snacks'),('69622e96d3cb441f5303c952','Chocolates','snacks'),('69622ea3d3cb441f5303cbed','Dates & Dried Fruit Snacks','snacks'),('69622f14d3cb441f53042549','Local Bites & Simsim','snacks'),
('69622f05d3cb441f530418fd','Spices, Seasoning & Baking','pantry'),('69622e9bd3cb441f5303cbb8','Cooking Oils & Fats','pantry'),('69622ef8d3cb441f5303e874','Sauces, Ketchup & Condiments','pantry'),('69622ebcd3cb441f5303ccaa','Canned Goods & Breakfast Cereals','pantry'),('69622e8ad3cb441f5303bcb5','Jams, Honey & Spreads','pantry'),('69622ef0d3cb441f5303db75','Rice & Grains','pantry'),('69622e8dd3cb441f5303bcc4','Beans, Lentils & Pulses','pantry'),('69622eb9d3cb441f5303cc90','Maize & Wheat Flour','pantry'),('69622ee3d3cb441f5303dad3','Pasta & Instant Noodles','pantry'),('69622ebfd3cb441f5303ccc5','Tinned Fruits & Toppings','pantry'),('69622f0fd3cb441f530424e0','Sugar & Sweeteners','pantry'),('69622eead3cb441f5303db22','Green Grams & Dry Cereals','pantry'),('696109d6d3cb441f53c1bd5f','Maize & Wheat Flour','pantry'),
('69622ee0d3cb441f5303daad','Fresh Milk, Lala & Milk Powder','fresh'),('69622eccd3cb441f5303cd3b','Ice Cream & Frozen Treats','fresh'),('69622e87d3cb441f5303bb6c','Bread, Buns & Bakery','fresh'),('69622edad3cb441f5303da62','Sausages, Tuna & Cold Cuts','fresh'),('69622e93d3cb441f5303c93b','Poultry & Chicken','fresh'),('69622e90d3cb441f5303bde4','Cheese & Dairy Fats','fresh'),('69622efbd3cb441f5303e8a1','Sausages, Tuna & Cold Cuts','fresh'),('69610d43d3cb441f53c30211','Bread, Buns & Bakery','fresh'),('69622eb5d3cb441f5303cc77','Fresh & Frozen Fish','fresh'),
('69622e9ed3cb441f5303cbca','Hair Care, Skin & Grooming','care'),('69622e74d3cb441f5303a18f','Bath Soaps & Body Wash','care'),('69622eddd3cb441f5303da88','Pain Relief & Wellness','care'),('69622f1ad3cb441f530425b6','Toothpaste & Oral Care','care'),
# inferred from product names (brief was cut off here)
('69622f17d3cb441f5304257f','Toothbrushes','care'),('69622ea5d3cb441f5303cc03','Deodorants & Fragrance','care'),('69622eedd3cb441f5303db4b','Hair Care, Skin & Grooming','care'),
('69622ef4d3cb441f5303dba7','Tissue, Sanitary & Home Essentials','household'),('69622ea8d3cb441f5303cc1d','Cleaning, Detergents & Air Fresheners','household'),('69622dc5d3cb441f5302dc42','Laundry Bars & Soaps','household'),('69622ed0d3cb441f5303cd5b','Insect Killers & Repellents','household'),
('69622ed3d3cb441f5303cd7c','Kitchen Tools & Bakeware','home'),('69622f1fd3cb441f53042627','Kitchenware & Food Storage','home'),('69622ee7d3cb441f5303dafa','Plasticware & Party Supplies','home'),('69622ec9d3cb441f5303cd1c','Hardware & Tools','home'),('69622ec6d3cb441f5303ccfe','General Merchandise','home'),('69622ec3d3cb441f5303cce1','Gas & Cooking Appliances','home'),
('69622f0cd3cb441f530424ad','Stationery & Art Supplies','school'),('69622f1cd3cb441f530425ee','Toys & Games','school'),('69622e98d3cb441f5303cba7','School Bags & Kids Accessories','school'),('69622e80d3cb441f5303bb5b','Bikes, Scooters & Balls','school'),('69622f08d3cb441f53041939','Bikes, Scooters & Balls','school'),
('69622eb2d3cb441f5303cc5f','Electricals & Electronics','tech'),('69622ed6d3cb441f5303cd9e','Bulbs & Torches','tech'),('69622e79d3cb441f5303b78d','Batteries','tech'),('69622ea1d3cb441f5303cbdb','Airtime & Vouchers','tech'),('69622f26d3cb441f5304333d','Watches & Wallets','tech'),('69622f23d3cb441f53043301','Watches & Wallets','tech'),('69622efed3cb441f5303f41b','Slippers & Footwear','tech'),('69622eafd3cb441f5303cc48','Electricals & Electronics','tech')]
assert len({m[0] for m in M})==60 and set(df['Category ID'])<= {m[0] for m in M}
slug=lambda s:re.sub(r'-+','-',re.sub(r'[^a-z0-9]+','-',s.lower())).strip('-')
AIS=[];AI={};CAT2A={}
for cid,lab,d in M:
    if lab not in AI: AI[lab]=len(AIS);AIS.append([slug(lab),lab,DI[d]])
    CAT2A[cid]=AI[lab]
AIS.append(['eggs','Eggs',DI['fresh']]);EGG=len(AIS)-1
# ---- name normalisation
SMALL={'and','of','with','for','in','to','the','a','on','or','&'}
ACR={'UHT','LED','USB','TV','AA','AAA','BBQ','PVC','OTC','ORS','SPF','XL','XXL','XS','DVD','CD','UK','USA','UV','DIY','HD','RTD','OK','KG','ML','LTR','PCS','PC','PKT','PKTS','GM','MG','CM','MM','NO','DJ','FM','AC','DC','SIM','GSM','VAT','ID','PP','PE','HP','LG','JBL','KFC','SOS','MSG','NB','XO','VSOP','WD','TWS','SSD','TDS','GB','TB','RAM'}
def tc_part(w,first):
    if not w: return w
    if re.search(r'\d',w): return w.upper()
    if w.upper() in ACR: return w.upper()
    if w.lower() in SMALL and not first: return w.lower()
    return w[:1].upper()+w[1:].lower()
def tc_token(t,first):
    parts=re.split(r"([/\-&*()+.,'’:])",t);out=[];f=first
    for p in parts:
        if re.fullmatch(r"[/\-&*()+.,'’:]",p) or p=='': out.append(p);continue
        out.append(tc_part(p,f));f=False
    return ''.join(out)
def norm(s):
    s=re.sub(r'\s+',' ',str(s)).strip()
    letters=[c for c in s if c.isalpha()]
    if letters and sum(c.islower() for c in letters)/len(letters)>0.15: return s  # already mixed case, keep
    toks=s.split(' ');return ' '.join(tc_token(t,i==0) for i,t in enumerate(toks))
# ---- OFF image derivation
def off_url(b):
    if not b or not b.isdigit(): return None
    if len(b)<=8: return f'https://images.openfoodfacts.org/images/products/{b}/front_en.400.jpg'
    b13=b.zfill(13)
    return f'https://images.openfoodfacts.org/images/products/{b13[0:3]}/{b13[3:6]}/{b13[6:9]}/{b13[9:]}/front_en.400.jpg'
rows=[];dropped=[];explicit=0;dd=0
for _,r in df.iterrows():
    name=str(r['Name']).strip()
    if re.match(r'^\s*test\b',name,re.I): dropped.append((r['Reference Number'],name));continue
    nm=norm(name)
    b=r['QR Code'];b=None if pd.isna(b) else re.sub(r'\.0$','',str(b).strip()) or None
    price=float(r['Price']);price=int(price) if price==int(price) else round(price,2)
    q=r['Quantity'];q=int(float(q)) if not pd.isna(q) else 0
    uom=r['UOM'];uom='PCS' if pd.isna(uom) or not str(uom).strip() else re.sub(r'\s+',' ',str(uom).strip()).upper()
    d=r['Description'];d=None if pd.isna(d) else norm(d)
    if not d or not (len(d)>len(nm) and d.lower().startswith(nm.lower())): d=nm  # only keep a description that extends the name
    img=r['Image URL'];img=None if pd.isna(img) or not str(img).startswith('https://images.openfoodfacts.org') else str(img)
    a=CAT2A[r['Category ID']]
    if nm.lower()=='eggs': a=EGG
    exp=''
    if img:
        der=off_url(b)
        if der!=img: exp=img;explicit+=1
    elif b and off_url(b): pass
    rows.append([r['Reference Number'],nm,b or 0,price,max(0,q),'' if uom=='PCS' else uom,a,'' if d==nm else d,1 if img else 0])
# images only where the source says so: flag column 9
print('rows',len(rows),'dropped',dropped,'explicit imgs',explicit,'with img flag',sum(r[8] for r in rows))
print('desc differs',sum(1 for r in rows if r[7]),'zero stock',sum(1 for r in rows if r[4]==0),'low',sum(1 for r in rows if 0<r[4]<=5))
import collections
print(collections.Counter(AIS[r[6]][1] for r in rows).most_common(8))
print([ (r[1]) for r in rows[:12]])
print('names changed sample:',[(df.iloc[i]['Name'].strip(),rows[i][1]) for i in range(0,6161,520) if i<len(rows)][:12])
json.dump({'D':D,'A':AIS,'P':rows},open('catalog.json','w'),separators=(',',':'),ensure_ascii=False)
import os;print('catalog bytes',os.path.getsize('catalog.json'))
