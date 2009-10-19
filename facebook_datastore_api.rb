# Facebook Data Store API Ruby Client
# by Clara Raubertas, Parallactic Consulting // 2009
# Licensed under MIT license (included)

require 'rubygems'
require 'curb'
require 'cgi'
require 'digest/md5'
require 'hpricot'
require 'json'

class FBStore

  attr_accessor :secret
  attr_accessor :api_key
  attr_accessor :session_key

  def initialize(secret, api_key, session_key = nil)
    self.secret = secret
    self.api_key = api_key
    self.session_key = session_key
  end

# utility functions

def generate_sig(params_array, secret)
  str = ''
  params_array = params_array.sort
  params_array.each { |key, value|  
    if value.is_a? Enumerable
      value = value.to_a.join(',')
    end
    str += "#{key}=#{value}"
}
  str += secret
  return Digest::MD5::hexdigest(str)

end



def post_request(method, params, session_key = nil)
  params['method'] = method
  if session_key
    params['session_key'] = session_key
  elsif self.session_key
    params['session_key'] = self.session_key
  end
  params['api_key'] = self.api_key
  params['call_id'] = Time.new.to_f.to_s
  params['v'] = '1.0'
  post_params = Array.new
  params.each { |key, value|  
    if value.is_a? Enumerable
      value = value.to_a.join(',')
    end
    if value.is_a? Integer
      value = value.to_s
    end
      post_params << key + '=' + CGI::escape(value)

}
  secret = self.secret
  post_params << 'sig=' + generate_sig(params, secret)
  post_string = post_params.join('&')
  c = Curl::Easy.new("http://api.facebook.com/restserver.php") do |curl|
    curl.headers["User-Agent"] = "Facebook API Ruby Client"
    curl.verbose = true
  end
  c.http_post(post_string)
  return c.body_str
end

def call_method(method, params, session_key = nil)
  xml = post_request(method, params, session_key)
  return xml
end


# user preference API

# takes an optional user id (if the user ID is not passed, the session key must be set)
# returns true on success
def setUserPreference(pref_id, value, uid = nil)
  params = { "pref_id" => pref_id, "value" => value}
  if uid
    params = params.merge({"uid" => uid})
  end
  xml = call_method('facebook.data.setUserPreference', params)
  handle_exceptions(xml)
  return true
end


# takes an optional user id (if the user ID is not passed, the session key must be set)
# returns true on success, raises an error otherwise
def setUserPreferences(values, uid = nil, replace = false)
  params = { "values" => values.to_json, "replace" => replace.to_s}
  if uid
    params = params.merge({"uid" => uid})
  end
  xml = call_method('facebook.data.setUserPreferences', params)
  handle_exceptions(xml)
  return true
end

# takes an optional user id (if the user ID is not passed, the session key must be set)
# returns the value of the requested preference
def getUserPreference(pref_id, uid = nil)
  params = { "pref_id" => pref_id }
  if uid
    params = params.merge({"uid" => uid})
  end
  xml = call_method('facebook.data.getUserPreference', params)
  handle_exceptions(xml)
  return CGI::unescapeHTML(Hpricot::XML(xml).search('data_getUserPreference_response').inner_html)
end

# takes an optional user id (if the user ID is not passed, the session key must be set)
# returns a hash of user preferences
def getUserPreferences(uid = nil)
  params = { }
  if uid
    params = params.merge({"uid" => uid})
  end
  xml = call_method('facebook.data.getUserPreferences', params)
  results = Hash.new
  for p in Hpricot::XML(xml).search('preference')
    results = results.merge({ CGI::unescapeHTML(Hpricot::XML(p.inner_html).search('pref_id').inner_html) => CGI::unescapeHTML(Hpricot::XML(p.inner_html).search('value').inner_html)})
  end
  return results
end

#object data definition API

def createObjectType(name)
  xml = call_method('facebook.data.createObjectType', { "name" => name })
  handle_exceptions(xml)
  return true
end

def dropObjectType(name)
  xml = call_method('facebook.data.dropObjectType', { "obj_type" => name })
  handle_exceptions(xml)
  return true
end

def renameObjectType(oldname, newname)
  xml = call_method('facebook.data.renameObjectType', { "obj_type" => oldname, "new_name" => newname })
  handle_exceptions(xml)
  return true
end

def defineObjectProperty(obj_name, prop_name, prop_type)
  xml = call_method('facebook.data.defineObjectProperty', { "obj_type" => obj_name, "prop_name" => prop_name, "prop_type" => prop_type})
  handle_exceptions(xml)
  return true
end

def undefineObjectProperty(obj_name, prop_name)
  xml = call_method('facebook.data.undefineObjectProperty', { "obj_type" => obj_name, "prop_name" => prop_name})
  handle_exceptions(xml)
  return true
end

def renameObjectProperty(obj_name, old_name, new_name)
  xml = call_method('facebook.data.renameObjectProperty', { "obj_type" => obj_name, "prop_name" => old_name, "new_name" => new_name })
  handle_exceptions(xml)
  return true
end

# returns an array of hashes, one hash for each property of the object
# the hash keys are "name" (the property name), "data type" (1, 2, or 3), and "index type"
def getObjectType(name)
  xml = call_method('facebook.data.getObjectType', { "obj_type" => name })
  results = Array.new
  for n in Hpricot::XML(xml).search('object_property_info')
    n = n.inner_html
    results << { "name" => CGI::unescapeHTML(Hpricot::XML(n).search('name').inner_html), "data_type" => CGI::unescapeHTML(Hpricot::XML(n).search('data_type').inner_html), "index_type" => CGI::unescapeHTML(Hpricot::XML(n).search('index_type').inner_html) }
  end
  handle_exceptions(xml)
  return results
end

# returns an array of the names of available object types
def getObjectTypes
  xml = call_method('facebook.data.getObjectTypes', { })
  results = Array.new
  for n in Hpricot::XML(xml).search('name')
    results << CGI::unescapeHTML(n.inner_html)
  end
  handle_exceptions(xml)
  return results
end

# Object Data Access


# returns the object ID of the created object
def createObject(obj_type, properties)  # create a new object
  xml = call_method('facebook.data.createObject', { "obj_type" => obj_type, "properties" => properties.to_json})
  handle_exceptions(xml)
  return CGI::unescapeHTML(Hpricot::XML(xml).search('data_createObject_response').inner_html)
end

# returns true if successful, raises an error otherwise
def updateObject(obj_id, properties, replace = 0) # update an object's properties
  xml = call_method('facebook.data.updateObject', { "obj_id" => obj_id, "properties" => properties.to_json, "replace" => replace})
  handle_exceptions(xml)
  return true
end

# returns true if successful
def deleteObject(obj_id) # delete an object by its id
  xml = call_method('facebook.data.deleteObject', { "obj_id" => obj_id})
  handle_exceptions(xml)
  return true
end

# obj_ids: an array of ids
def deleteObjects(obj_ids) # delete multiple objects by ids
  xml = call_method('facebook.data.deleteObjects', { "obj_ids" => obj_ids.to_json})
  handle_exceptions(xml)
  return true
end

# returns an array of the values requested
def getObject(obj_id, prop_names = nil) # get an object's properties by its id
  params = { "obj_id" => obj_id}
  if prop_names
    params = params.merge({ "prop_names" => prop_names.to_json })
  end
  xml = call_method('facebook.data.getObject', params)
  handle_exceptions(xml)
  results = Array.new
  for r in Hpricot::XML(xml).search('data_getObject_response_elt')
    results << CGI::unescapeHTML(r.inner_html)
  end
  return results
end

# returns an array of arrays
def getObjects(obj_ids) # get properties of a list of objects by ids
  xml = call_method('facebook.data.getObjects', { "obj_ids" => obj_ids.to_json })
  handle_exceptions(xml)
  results = Array.new
  for r in Hpricot::XML(xml).search('data_getObjects_response_elt')
    values = Array.new
    for v in Hpricot::XML(r.inner_html).search('data_getObjects_response_elt_elt')
      values << CGI::unescapeHTML(v.inner_html)
    end
    results << values
  end
  return results
end

# returns the value of the property
def getObjectProperty(obj_id, prop_name) # get an object's one property
  xml = call_method('facebook.data.getObjectProperty', { "obj_id" => obj_id, "prop_name" => prop_name})
  handle_exceptions(xml)
  return CGI::unescapeHTML(Hpricot::XML(xml).search('data_getObjectProperty_response').inner_html)
end

# returns true if successful
def setObjectProperty(obj_id, prop_name, value) # set an object's one property
  xml = call_method('facebook.data.setObjectProperty', { "obj_id" => obj_id, "prop_name" => prop_name, "prop_value" => value})
  handle_exceptions(xml)
  return true
end

# returns the value of the property queried, or nil if nothing is found
def getHashValue(obj_type, key, prop_name) # get a property value by a hash key
  xml = call_method('facebook.data.getHashValue', { "obj_type" => obj_type, "key" => key, "prop_name" => prop_name})
  handle_exceptions(xml)
  result = Hpricot::XML(xml).search('data_getHashValue_response').inner_html
  if result == ''
    return nil
  else
    return CGI::unescapeHTML(result)
  end
end

# returns the ID of the new object that's been created
def setHashValue(obj_type, key, value, prop_name) # set a property value by a hash key
  xml = call_method('facebook.data.setHashValue', { "obj_type" => obj_type, "key" => key, "prop_name" => prop_name, "value" => value})
  handle_exceptions(xml)
  return CGI::unescapeHTML(Hpricot::XML(xml).search('data_setHashValue_response').inner_html)
end

# returns the new value of the property after incrementing
def incHashValue(obj_type, key, prop_name, increment = 1) # increment/decrement a property value by a hash key
  xml = call_method('facebook.data.incHashValue', { "obj_type" => obj_type, "key" => key, "prop_name" => prop_name, "increment" => increment})
  handle_exceptions(xml)
  return CGI::unescapeHTML(Hpricot::XML(xml).search('data_incHashValue_response').inner_html)
end

# returns true on success
def removeHashKey(obj_type, key)  # delete an object by its hash key
  xml = call_method('facebook.data.removeHashKey', { "obj_type" => obj_type, "key" => key})
  handle_exceptions(xml)
  return true
end

# returns true on success
def removeHashKeys(obj_type, keys) # delete multiple objects by their hash keys
  xml = call_method('facebook.data.removeHashKeys', { "obj_type" => obj_type, "keys" => keys.to_json})
  handle_exceptions(xml)
  return true
end

# Association Data Definition API

# returns true on success
def defineAssociation(name, assoc_type, assoc_info1, assoc_info2, inverse = nil)  # create a new object association
  if inverse
    xml = call_method('facebook.data.defineAssociation', { "name" => name, "assoc_type" => assoc_type, "assoc_info1" => assoc_info1.to_json, "assoc_info2" => assoc_info2.to_json, "inverse" => inverse})
  else
    xml = call_method('facebook.data.defineAssociation', { "name" => name, "assoc_type" => assoc_type, "assoc_info1" => assoc_info1.to_json, "assoc_info2" => assoc_info2.to_json})
  end
  handle_exceptions(xml)
  return true
end

# returns true on success
def undefineAssociation(name) # remove a previously defined association and all its data
  xml = call_method('facebook.data.undefineAssociation', { "name" => name })
  handle_exceptions(xml)
  return true
end

# returns true on success
def renameAssociation(oldname, newname, new_alias1 = nil, new_alias2 = nil) # rename a previously defined association
  params = { "name" => oldname, "new_name" => newname }
  if new_alias1
    params = params.merge({"new_alias1" => new_alias1})
  end
  if new_alias2
    params = params.merge({"new_alias2" => new_alias2})
  end
  xml = call_method('facebook.data.renameAssociation', params)
  handle_exceptions(xml)
  return true
end

# returns a hash of "name" (the name) and "assoc_info1" and "assoc_info2"
# "assoc_info1" and "assoc_info2" are both hashes of "alias", "object_type", and "unique"
def getAssociationDefinition(name) # get definition of a previously defined association
  xml = call_method('facebook.data.getAssociationDefinition', { "name" => name })
  assoc_info1 = Hpricot::XML(xml).search('assoc_info1_elt')
  assoc_info1_hash = { "alias"=> CGI::unescapeHTML(assoc_info1[0].inner_html), "object_type" => CGI::unescapeHTML(assoc_info1[1].inner_html), "unique" => CGI::unescapeHTML(assoc_info1[2].inner_html)}
  assoc_info2 = Hpricot::XML(xml).search('assoc_info2_elt')
  assoc_info2_hash = { "alias"=> CGI::unescapeHTML(assoc_info2[0].inner_html), "object_type" => CGI::unescapeHTML(assoc_info2[1].inner_html), "unique" => CGI::unescapeHTML(assoc_info2[2].inner_html)}

  return { "name" => CGI::unescapeHTML(Hpricot::XML(xml).search('name').inner_html), "assoc_type" => CGI::unescapeHTML(Hpricot::XML(xml).search('assoc_type').inner_html), "assoc_info1" => assoc_info1_hash, "assoc_info2" => assoc_info2_hash }
end

# returns an array of assoc definitions; each def is formatted the same as the results from getassociationdefinition
def getAssociationDefinitions # get definitions of all previously defined associations
  xml = call_method('facebook.data.getAssociationDefinitions', { })
  results = Array.new
  for row in Hpricot::XML(xml).search('object_assoc_info')
    assoc_info1 = Hpricot::XML(row.inner_html).search('assoc_info1_elt')
    assoc_info1_hash = { "alias"=> CGI::unescapeHTML(assoc_info1[0].inner_html), "object_type" => CGI::unescapeHTML(assoc_info1[1].inner_html), "unique" => CGI::unescapeHTML(assoc_info1[2].inner_html)}
    assoc_info2 = Hpricot::XML(row.inner_html).search('assoc_info2_elt')
    assoc_info2_hash = { "alias"=> CGI::unescapeHTML(assoc_info2[0].inner_html), "object_type" => CGI::unescapeHTML(assoc_info2[1].inner_html), "unique" => CGI::unescapeHTML(assoc_info2[2].inner_html)}
    
    results << { "name" => CGI::unescapeHTML(Hpricot::XML(row.inner_html).search('name').inner_html), "assoc_type" => CGI::unescapeHTML(Hpricot::XML(row.inner_html).search('assoc_type').inner_html), "assoc_info1" => assoc_info1_hash, "assoc_info2" => assoc_info2_hash }
  end
  return results
end

# Association Data Access API

# returns true on success
def setAssociation(name, obj_id1, obj_id2, data = nil, assoc_time = nil) # create an association between two objects
  params = { "name" => name, "obj_id1" => obj_id1, "obj_id2" => obj_id2 }
  unless data.nil?
   params = params.merge({"data" => data})
  end
  unless assoc_time.nil?
    params = params.merge({"assoc_time" => assoc_time})
  end
  xml = call_method("facebook.data.setAssociation", params)
  handle_exceptions(xml)
  return true
end

# takes a list of assocs and an optional name
# returns true on success
def setAssociations(assocs, name = nil) # create a list of associations between pairs of objects
  params = { "assocs" => assocs.to_json }
  if name
    params = params.merge({"name" => name})
  end
  xml = call_method("facebook.data.setAssociations", params)
  handle_exceptions(xml)
  return true
end

# returns true on success
def removeAssociation(name, obj_id1, obj_id2) # remove an association between two objects
  xml = call_method('facebook.data.removeAssociation', { "name" => name, "obj_id1" => obj_id1, "obj_id2" => obj_id2 })
  handle_exceptions(xml)
  return true
end

# returns true on success
def removeAssociations(assocs, name = nil) # remove associations between pairs of objects
  params = { "assocs" => assocs.to_json }
  if name
    params = params.merge({"name" => name})
  end
  xml = call_method("facebook.data.removeAssociations", params)
  handle_exceptions(xml)
  return true
end

# note: name is misleading! this removes ASSOCIATIONS, not the actual objects
# returns true on success
def removeAssociatedObjects(name, obj_id) # remove all associations of an object
  xml = call_method('facebook.data.removeAssociatedObjects', { "name" => name, "obj_id" => obj_id})
  handle_exceptions(xml)
  return true
end

# returns an array of hashes
def getAssociatedObjects(name, obj_id, no_data = true) # get ids of an object's associated objects
  xml = call_method("facebook.data.getAssociatedObjects", { "name" => name, "obj_id" => obj_id, "no_data" => no_data.to_s })
  handle_exceptions(xml)
  results = Array.new
  for row in Hpricot::XML(xml).search('object_association')
    results << { "id2" => CGI::unescapeHTML(Hpricot::XML(row.inner_html).search('id2').inner_html), "data" => CGI::unescapeHTML(Hpricot::XML(row.inner_html).search('data').inner_html), "time" => CGI::unescapeHTML(Hpricot::XML(row.inner_html).search('time').inner_html) }
  end
  return results
end

# returns the number of objects (integer)
def getAssociatedObjectCount(name, obj_id) # get count of an object's associated objects
  xml = call_method("facebook.data.getAssociatedObjectCount", { "name" => name, "obj_id" => obj_id})
  handle_exceptions(xml)
  return Hpricot::XML(xml).search('data_getAssociatedObjectCount_response').inner_html.to_i
end

# returns an array of integers
def getAssociatedObjectCounts(name, ids) # get counts of associated objects of a list of objects.
  xml = call_method("facebook.data.getAssociatedObjectCounts", { "name" => name, "obj_ids" => ids.to_json})
  handle_exceptions(xml)
  results = Array.new
  for row in Hpricot::XML(xml).search('data_getAssociatedObjectCounts_response_elt')
    results << row.inner_html.to_i
  end
  return results
end

# returns an array of hashes
def getAssociations(obj_id1, obj_id2, no_data = false) # get all associations between two objects
  xml = call_method("facebook.data.getAssociations", { "obj_id1" => obj_id1, "obj_id2" => obj_id2, "no_data" => no_data.to_s })
  results = Array.new
  for row in Hpricot::XML(xml).search('object_association')
    results << { "id1" => CGI::unescapeHTML(Hpricot::XML(row.inner_html).search('id1').inner_html), "id2" => CGI::unescapeHTML(Hpricot::XML(row.inner_html).search('id2').inner_html), "data" => CGI::unescapeHTML(Hpricot::XML(row.inner_html).search('data').inner_html), "time" => CGI::unescapeHTML(Hpricot::XML(row.inner_html).search('time').inner_html) }
  end
  return results
end


# handles exceptions for any of these functions

def handle_exceptions(xml)
  unless Hpricot::XML(xml).search('error_response').empty?
    raise Hpricot::XML(xml).search('error_msg').inner_html
  end
end


end



