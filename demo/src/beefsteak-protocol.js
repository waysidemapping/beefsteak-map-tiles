import Pbf from 'https://unpkg.com/pbf@4.0.1/index.js';
import {VectorTile} from 'https://esm.run/@mapbox/vector-tile@2.0.3/index.js';
import tileToProtobuf from 'https://esm.run/vt-pbf@3.1.3/index.js';

export async function beefsteakProtocolFunction(request) {
  const url = request.url.replace('beefsteak://', '');
  return fetch(url)
    .then((response) => response.arrayBuffer())
    .then((buffer) => new VectorTile(new Pbf(buffer)))
    .then(processIncomingBeefsteakTile)
    .then((tile) => tileToProtobuf(tile).buffer)
    .then((data) => ({ data }));
}

function processIncomingBeefsteakTile(tile) {
  const relationLayer = tile.layers.relation;
  const relationCount = relationLayer?.length;
  if (!(relationCount > 0)) return tile;
  const allRelationKeys = relationLayer._keys;
  const allRelationKeysCount = allRelationKeys.length;
  const relationsById = {};
  for (let i = 0; i < relationCount; i += 1) {
    let relation = relationLayer.feature(i);
    relationsById[Math.floor(relation.id * 0.1)] = relation;
  }
  
  for (const layerId in tile.layers) {
    const layer = tile.layers[layerId];
    tile.layers[layerId] = {
      ...layer,
      feature: getWrappedFeatureFunction(layer)
    };
  }
  return tile;

  function getWrappedFeatureFunction(layer) {
    return function wrappedFeatureFunction(index) {
      const feature = layer.feature(index);
      const featureProperties = feature.properties;

      if (feature.id) {
        // add OSM ID info as properties for convenience 
        featureProperties['osm.id'] = osmIdFromBeefsteakFeatureId(feature.id);
        featureProperties['osm.type'] = osmTypeFromBeefsteakFeatureId(feature.id);
      }
      const featureKeys = Object.keys(feature.properties);

      if (feature.id % 10 === 3) { // relation
        if (featureKeys.length === 0) {
          // for relations with no properties, attempt to populate with data from the relation layer

          const id = Math.floor(feature.id * 0.1);
          const relation = relationsById[id];

          if (relation) {
            for (const prop in relation.properties) {
              featureProperties[prop] = relation.properties[prop];
            }
          }
        }

      } else if (allRelationKeysCount) { // non-relation
        // Based on relation memberships in the form `m.{relation_id}={member_role}`,
        // add the relation tags to the feature in the form `r.{relation_key}=┃{relation1_value}┃{relation2_value}┃`

        const linkedRelations = [];
        for (let i = 0; i < featureKeys.length; i+=1) {
          const key = featureKeys[i];
          if (key[0] === 'm' && key[1] === '.') {
            const id = Number(key.slice(2));
            const rel = relationsById[id];
            if (rel) linkedRelations.push(rel);
          }
        }
        // we need deterministic ordering so the same relation is always represented as the same index
        linkedRelations.sort((a, b) => a.id - b.id);

        const linkedRelationsCount = linkedRelations.length;

        if (linkedRelationsCount) {

          for (let i = 0; i < allRelationKeysCount; i+=1) {
            const key = allRelationKeys[i];
            let out = '┃';
            let hasValue = false;

            for (let j = 0; j < linkedRelationsCount; j+=1) {
              const value = linkedRelations[j].properties[key];
              if (value != null && value !== '') hasValue = true;
              out += (value ?? '') + '┃';
            }

            // only add the property if at least one of the relations has a value
            if (hasValue) featureProperties['r.' + key] = out;
          }
        }
      }
      return feature;
    }
  }
}

function osmIdFromBeefsteakFeatureId(id) {
  return !isNaN(id) && Math.floor(id / 10);
}

function osmTypeFromBeefsteakFeatureId(id) {
  switch (id % 10) {
    case 1: return 'n';
    case 2: return 'w';
    case 3: return 'r';
    default: return null;
  }
}