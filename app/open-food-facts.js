import {nutrients} from './data.js';
// OFF v2 *_100g fields are standardized to grams, except energy in kcal/kJ.
const fields={protein:'proteins',carbs:'carbohydrates',fat:'fat',fiber:'fiber',vitA:'vitamin-a',vitC:'vitamin-c',vitD:'vitamin-d',vitE:'vitamin-e',vitK:'vitamin-k',b1:'vitamin-b1',b2:'vitamin-b2',b6:'vitamin-b6',b12:'vitamin-b12',folate:'vitamin-b9',calcium:'calcium',iron:'iron',magnesium:'magnesium',potassium:'potassium',zinc:'zinc',selenium:'selenium',omega3:'omega-3-fat'};
export function productToFood(product,barcode) {
 const n=product?.nutriments;
 if(!n||!product.product_name?.trim())throw Error('This product has no usable name or nutrition data. Create a custom food from its label.');
 const number=v=>typeof v==='number'&&Number.isFinite(v)&&v>=0?v:null;
 const kcal=number(n['energy-kcal_100g'])??(number(n.energy_100g)===null?null:n.energy_100g/4.184);
 if(kcal===null)throw Error('This product has no calorie information. Create a custom food from its label.');
 const values=Object.fromEntries(nutrients.map(item=>{const raw=number(n[fields[item.id]+'_100g']);const factor=item.unit==='mg'?1000:item.unit==='µg'?1e6:1;return [item.id,raw===null?null:Math.round(raw*factor*1e6)/1e6];}));
 // Prefer total carbohydrate when supplied; do not guess an unreported total.
 if(number(n['carbohydrates-total_100g'])!==null)values.carbs=n['carbohydrates-total_100g'];
 return {id:'off-'+barcode,name:product.product_name.trim().slice(0,100),serving:'100 g (use 0.3 servings for 30 g)',emoji:'▤',calories:Math.round(kcal*100)/100,values,source:'Open Food Facts',barcode};
}
export async function lookupBarcode(barcode){
 if(!/^\d{8,14}$/.test(barcode))throw Error('Enter 8–14 digits from the package barcode.');
 const response=await fetch(`https://world.openfoodfacts.org/api/v2/product/${barcode}.json?fields=product_name,nutriments&app_name=Nutrient`,{signal:AbortSignal.timeout(15000)});
 if(!response.ok)throw Error('Food lookup is unavailable right now. Try again or create a custom food.');
 const data=await response.json();
 if(data.status!==1)throw Error('No product found for this barcode. You can create a custom food instead.');
 return productToFood(data.product,barcode);
}
