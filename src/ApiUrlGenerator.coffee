# Register functions to generator API URLs
#
# Features:
#    -  if a generator callback function has a parameter named 'objectPath',
#       any dots in the argument passed will be converted to slashes
class ApiUrlGenerator

    # @param urlRoot (string) prefixed to all generated URLs
    constructor: (@urlRoot = '') ->
        @generators = {}
        @optionalParams = []
        @params = []

    # @param type (string) Name of URL type (will overwrite any generator with same type)
    # @param callback (function) Function that returns an array of URL components
    # @param optionalParams (array, optional) Array of parameter names that are optional
    #           components *in the resulting URL*
    register: (type, callback, optionalParams = []) ->
        @generators[type] = callback
        @optionalParams[type] = optionalParams
        @params[type] = @_extractFunctionParams callback

    # returns a URL string of the given type, using the parameters
    # @param type (string) Matches one of the generators registered
    # and then a variable number of parameters, as required by the particular generator callback
    generateUrl: (type, params...) =>
        throw new Error "No API URL generator registered for #{type}" unless @generators[type]
        objectPathParamIndex = @params[type].indexOf('objectPath')
        params[objectPathParamIndex] = @_normaliseObjectPath params[objectPathParamIndex] if objectPathParamIndex
        @_buildUrl type, @generators[type].apply @, params

    # returns an array of function parameter names
    _extractFunctionParams: (f) ->
        m = f.toString().match /^function +\(([^)]*)\)/i
        param.trim() for param in m[1].split ','

    # converts foo.bar to foo/bar
    _normaliseObjectPath: (objectPath = '') =>
        objectPath.replace /[.\/]+/g, '/'

    _buildUrl: (type, parts) ->
        filteredParams = for part, i in parts when part or @optionalParams[type].indexOf(@params[i]) != -1
            # encode part (avoiding encoding slashes)
            (encodeURIComponent p for p in part.split '/').join '/'
        "#{@urlRoot}/#{filteredParams.join '/'}"

module.exports = ApiUrlGenerator
