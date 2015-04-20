"Copyright 2013 Patrick Smith"

root = exports ? this

dayInAMonth = 30

#hoverlyticsProfileConfig = require('../-config/main-config-gel')
hoverlyticsProfileConfig = require('hoverlytics-profile-config')


class root.Profile extends Backbone.Model
	initialize: ->
		now = new Date()
		startDate = new Date()
		startDate.setDate(now.getDate() - dayInAMonth + 1)
		@set(startDate: startDate, endDate: now)
		
		window.addGoogleClientAPIReadyCallback =>
			@googleClientAPIReady()
		
		return
		
		
	googleClientAPIReady: ->
		gapi.client.setApiKey(hoverlyticsProfileConfig.googleAPIKey)
		
		checkGoogleAuthorization = =>
			@checkGoogleAuthorization()
		
		window.setTimeout(checkGoogleAuthorization, 1)
		
		return
	
	
	checkGoogleAuthorization: (options) ->
		performAuthorization = options?.performAuthorization
		gapi.auth.authorize {
			client_id: hoverlyticsProfileConfig.googleClientID,
			scope: hoverlyticsProfileConfig.googleAPIScopes,
			immediate: not performAuthorization,
			cookie_policy: 'single_host_origin'
		}, (authorizationResult) =>
			@handleGoogleAuthorizationResult(authorizationResult)
		
		return
	
	
	signOutOfGoogle: ->
		token = gapi.auth.getToken()
		if token?.access_token?
			#console.log('Sign out of token', token)
			revokeUrl = "https://accounts.google.com/o/oauth2/revoke?token=#{token.access_token}"
			jQuery.ajax({
				type: 'GET'
				url: revokeUrl
				contentType: 'application/json'
				dataType: 'jsonp'
				success: =>
					@set('isAuthorized', false)
				error: (error) =>
					@set('isAuthorized', false)
			})
		
		gapi.auth.setToken(null)
		gapi.auth.signOut()
	
	
	performGoogleAuthorization: =>
		@checkGoogleAuthorization(performAuthorization: true)
		
		return
	
	
	handleGoogleAuthorizationResult: (authorizationResult) =>
		#console.log('profile: handleGoogleAuthorization result', authorizationResult);
		if authorizationResult?.access_token?
			gapi.client.load 'analytics', 'v3', =>
				#console.log('profile: analytics api loaded');
				@set('isAuthorized', true)
		else
			@set('isAuthorized', false)
		
		return
	
	
	requestListOfAccounts: =>
		#console.log('requestListOfAccounts')
		gapi.client.analytics.management.profiles.list(accountId: "~all", webPropertyId: "~all").execute (accountsResults) =>
			accountsList = accountsResults.items
			#console.log('ACCOUNTS LIST', accountsResults);
			@set('accountsList', accountsList)
	
	
	requestResultsWithOptions: (options = {}) =>
		return new AnalyticsResults _.extend(@pick(['profileID', 'startDate', 'endDate']), options)



AnalyticsResults = class root.AnalyticsResults extends Backbone.Model
	defaults: =>
		pageURL: null,
		activeSourceID: null
	
	initialize: ->
		@statIDsToRawResults = {}
		@reliedStatIDsToDerivedStatIDs = {}
		@waitedStatIDsToDerivedStatIDs = {}
		
		@listenTo(this, 'change:pageURL', @invalidateStats)
		
		return
	
	
	get: (attribute) =>
		value = Backbone.Model::get.call(this, attribute)
		return value if value?
		
		@requestValueForStatID attribute
		return
	
	
	requestValueForStatID: (statID) =>
		#console.log('requestValueForStatID:', statID);
		if googleClientAPIHasLoaded and @allStatIDs statID
			return @loadResultsForStatID statID
		else
			return null
	
	
	loadResultsForStatID: (requestedStatID) =>
		#console.log 'loadResultsForStatID:', requestedStatID
		statResults = @statIDsToRawResults[requestedStatID]
		
		return statResults if statResults?.loading
		
		statResults = {loading: true}
		@statIDsToRawResults[requestedStatID] = statResults
		
		requestInfo = @requestInfoForStatID(requestedStatID)
		#console.log 'REQUEST INFO', requestedStatID, requestInfo
		if requestInfo.reliesOn
			reliedStatID = requestInfo.reliesOn
			
			@reliedStatIDsToDerivedStatIDs[reliedStatID] ?= []
			@reliedStatIDsToDerivedStatIDs[reliedStatID].push(requestedStatID)
			#console.log 'Derived stat', requestedStatID, 'relies on:', reliedStatID
			
			reliedStatResults = @statIDsToRawResults[reliedStatID]
			# Only go ahead if relied stat's results have loaded or are loading, or, if they aren't loaded, then if this stat doesn't have its own query.
			if reliedStatResults or not requestInfo.query?
				if not reliedStatResults?
					#console.log 'Relied stat needs loading', reliedStatID)
					@loadResultsForStatID(reliedStatID)
				else if reliedStatResults.loaded
					#console.log 'Relied stat needs is loaded', reliedStatID
					@processResultsForStatInfo(requestInfo, reliedStatResults.rawResults)
					
				return statResults
		else if requestInfo.waitsOn
			waitsOnStatIDs = requestInfo.waitsOn
			
			hasGoAhead = true
			
			for waitedOnStatID in waitsOnStatIDs
				@waitedStatIDsToDerivedStatIDs[waitedOnStatID] ?= []
				@waitedStatIDsToDerivedStatIDs[waitedOnStatID].push(requestedStatID)
				
				waitedStatResults = @statIDsToRawResults[waitedOnStatID]
				if not waitedStatResults?
					hasGoAhead = false
					break
			
			if not hasGoAhead
				return statResults	
		
		
		query = requestInfo.query.call(this)
		
		#console.log 'Load stat', requestedStatID
		#console.log 'Load query', requestedStatID, query
		#console.time 'Load query ' + requestedStatID
		gapi.client.analytics.data.ga.get(query).execute (rawResults) =>
			#console.timeEnd 'Load query ' + requestedStatID
			
			@processResultsForStatInfo(requestInfo, rawResults)
		
		return statResults
	
	
	processResultsForStatInfo: (requestInfo, rawResults) =>
		statID = requestInfo.statID
		
		return false unless rawResults?
		
		if rawResults.error?
			return false
		
		#console.log('Got results', statID, rawResults)
		
		try
			processedResults = requestInfo.processResults.call(this, rawResults)
		catch exception
			#console.log 'Problem loading:', statID, exception
			throw exception
			processedResults = null
		
		return false unless processedResults?
		
		#console.log 'Got results', statID, rawResults, processedResults
		@statIDsToRawResults[statID] = {loaded: true, rawResults: rawResults}
		@set(statID, processedResults)
		
		# If any stats rely on this stat's results, process them now.
		if @reliedStatIDsToDerivedStatIDs[statID]
			#console.log 'Processing derived stats', @reliedStatIDsToDerivedStatIDs[statID]
			for derivedStatID in @reliedStatIDsToDerivedStatIDs[statID]
				@processResultsForStatInfo(@requestInfoForStatID(derivedStatID), rawResults)
		
		# If any stats were waiting for this stat to complete, request that they load now.
		if @waitedStatIDsToDerivedStatIDs[statID]
			for derivedStatID in @waitedStatIDsToDerivedStatIDs[statID]
				@loadResultsForStatID(derivedStatID)
		
		return
		
		
	invalidateStats: =>
		for statID, value of @allStatIDs()
			@unset(statID)
		
		@statIDsToRawResults = {}
		
		return
	
	
	getResultsForMonthBefore: =>
		if not @resultsForMonthBefore?
			options = @pick(['profileID', 'startDate', 'endDate', 'pageURL'])
			dayOffset = d3.time.day.offset
			date = options.startDate
			options.startDate = dayOffset(date, -dayInAMonth - 1)
			options.endDate = dayOffset(date, -1)
			
			@resultsForMonthBefore = new @constructor(options)
		
		return @resultsForMonthBefore
	
	
	baseQuery: =>
		query = {
			'ids': "ga:#{@get('profileID')}"
		}
		
		pageURL = @get('pageURL')
		if pageURL
			#query['filters'] = ('ga:pagePath==' + pageURL)
			# Instead of matching just the basic URL, use a regex to include ones with an added query or hash.
			# Regex from http://stackoverflow.com/a/13157996
			regexEscapedPageURL = pageURL.replace /[\-\[\]{}()*+?.,\\\^$|\#\s]/g, "\\$&"
			query['filters'] = ('ga:pagePath=~^' + regexEscapedPageURL + '/?([?].*)?([\#].*)?$')
		
		activeSourceID = @get('activeSourceID')
		#console.log 'BUILD QUERY activeSourceID:', activeSourceID
		if activeSourceID
			query = @combineQueries(query, {
				'filters': 'ga:source==' + activeSourceID
			})
			
		
		compareNewVsReturning = @get('compareNewVsReturning')
		#console.log 'BUILD QUERY activeSourceID:', activeSourceID
		if compareNewVsReturning
			query = @combineQueries(query, {
				'dimensions': 'ga:visitorType'
			})
			
		
		return query
	
	
	combineQueries: (queries...) =>
		finalQuery = {}
		
		filterList = []
		dimensionsList = []
		metricsList = []
		
		for query in queries
			basicQuery = _.omit(query, 'filters', 'dimensions', 'metrics')
			_.extend(finalQuery, basicQuery)
			
			if query['filters']?
				filterList.push(query['filters'])
			
			if query['dimensions']?
				dimensionsList.push(query['dimensions'])
			
			if query['metrics']?
				metricsList.push(query['metrics'])
			
		
		if filterList.length isnt 0
			finalQuery['filters'] = filterList.join ';'
		
		if dimensionsList.length isnt 0
			finalQuery['dimensions'] = dimensionsList.join ','
		
		if metricsList.length isnt 0
			finalQuery['metrics'] = metricsList.join ','
		
		
		return finalQuery
	
	
	queryForBetweenSetDates: =>
		_.extend @baseQuery(),
			'start-date': AnalyticsResults.displayDateForGoogleAPI @get 'startDate'
			'end-date': AnalyticsResults.displayDateForGoogleAPI @get 'endDate'
			'max-results': 50
	
	queryForToday: =>
		#console.log 'queryForBetweenSetDates:', @get 'startDate'
		displayedDate = AnalyticsResults.displayDateForGoogleAPI new Date()
		_.extend @baseQuery(),
			'start-date': displayedDate,
			'end-date': displayedDate
		
	
	queryForTotalAcrossAllTime: =>
		_.extend @baseQuery(),
			'start-date': '2005-01-01',
			'end-date': '2030-01-01',
			'max-results': 1
		
	
	queryComparingNewVsReturningVisitors: =>
		'dimensions': 'ga:visitorType'
	
	
	requestInfoForStatID: (statID) =>
		requestInfo = @statIDsToHandlers[statID]
		requestInfo.statID = statID
		
		return requestInfo
	
	
	processResultsForDailyUniqueVisitors: (rawResults, options) =>
		rows = rawResults.rows
		compareNewVsReturning = options?.compareNewVsReturning
		
		indexes = rawResults.columnIndexes = if compareNewVsReturning
				visitorType: 0,
				date: 1,
				visitorCount: 2
			else
				date: 0,
				visitorCount: 1
		
		
		datesToRowGroups = _.groupBy rows, (row) =>
			row[indexes.date]
		
		
		unsortedInfo = for dateCompressed, rowGroup of datesToRowGroups
			year = parseInt dateCompressed.substring(0, 4), 10
			month = parseInt dateCompressed.substring(4, 6), 10
			day = parseInt dateCompressed.substring(6, 8), 10
			info = {date: new Date(year, month - 1, day), visitorCount: 0}
			
			if compareNewVsReturning
				for row in rowGroup
					visitorCount = parseInt row[indexes.visitorCount], 10
					if row[indexes.visitorType] is 'New Visitor'
						info.newVisitorCount = visitorCount
					else
						info.returningVisitorCount = visitorCount
					
					info.visitorCount += visitorCount
			else
				row = rowGroup[0]
				info.visitorCount = parseInt row[indexes.visitorCount], 10
			
			info
		
		sortedInfo = _.sortBy unsortedInfo, (info) =>
			+info.date
		
		return sortedInfo
	
	
	statIDsToHandlers:
	
		dailyUniqueVisitors:
			query: ->
				@combineQueries @queryForBetweenSetDates(),
					'dimensions': 'ga:date',
					'metrics': 'ga:visitors',
					'sort': 'ga:date',
					'max-results': 120
			
			processResults: (rawResults) ->
				return @processResultsForDailyUniqueVisitors rawResults
		
		
		dailyUniqueVisitorsWithNewVsReturningCompared:
			query: ->
				@combineQueries @queryForBetweenSetDates(),
					@queryComparingNewVsReturningVisitors(),
					'dimensions': 'ga:date',
					'metrics': 'ga:visitors',
					'sort': 'ga:date',
					'max-results': 120
			
			processResults: (rawResults) ->
				return @processResultsForDailyUniqueVisitors rawResults,
					compareNewVsReturning: true
			
		
		###
		todaysUniqueVisitors:
			reliesOn: "dailyUniqueVisitors",
			processResults: (rawResults) ->
				rowForCurrentDate = _.last rawResults.rows
				return rowForCurrentDate?[1]
		
		###
		
		
		todaysUniqueVisitors:
			query: ->
				@combineQueries @queryForToday(), {
					'dimensions': 'ga:date'
					'metrics': 'ga:visitors'
					'max-results': 1
				}
			
			processResults: (rawResults) ->
				return rawResults.rows[0][1]
		
		
		visitorsCount:
			query: ->
				@combineQueries @queryForBetweenSetDates(), {
					'metrics': 'ga:visitors'
					#'max-results': 1
				}
			
			processResults: (rawResults) ->
				return rawResults.rows[0]?[0] ? 0
		
		###
			reliesOn: "dailyUniqueVisitors",
			processResults: (rawResults) ->
				return _.reduce rawResults.rows, (count, row) ->
					count + parseInt row[rawResults.columnIndexes.visitorCount], 10
				, 0
		###
		
		
		pastWeekVisitorsCount:
			reliesOn: "dailyUniqueVisitors",
			processResults: (rawResults) ->
				return _.reduce _.last(rawResults.rows, 7), (count, row) ->
					return count + parseInt row[rawResults.columnIndexes.visitorCount], 10
				, 0
		
		
		todaysTopSource:
			query: ->
				@combineQueries @queryForToday(), {
					'dimensions': 'ga:source'
					'metrics': 'ga:visitors'
					'sort': '-ga:visitors'
					#'filters': 'ga:source!=(direct)',
					'max-results': 1
				}
			
			processResults: (rawResults) ->
				if rawResults.rows?.length > 0
					row = rawResults.rows[0]
					return sourceID: row[0], visitorCount: parseInt(row[1], 10)
				else
					return null
		
		
		###
		topSources: {
			query: function() {
				return owner.combineQueries(owner.queryForBetweenSetDates(), {
					'dimensions': 'ga:source',
					'metrics': 'ga:visitors',
					'sort': '-ga:visitors',
					'max-results': 5
				});
			},
			processResults: function(rawResults) {
				return _.map(rawResults.rows, function(row) {
					return {sourceID: row[0], visitorCount: parseInt(row[1], 10)};
				});
			}
		},
		###
		
		
		topSources:
			waitsOn: ['engagement']
			
			query: ->
				@combineQueries @queryForBetweenSetDates(), {
					'dimensions': 'ga:source, ga:socialNetwork'
					'metrics': 'ga:visitors, ga:avgTimeOnPage, ga:entranceRate'
					'sort': '-ga:visitors'
					#'filters': 'ga:hasSocialSourceReferral==Yes'
					'max-results': 7
				}
			
			processResults: (rawResults) ->
				if rawResults.totalResults is 0
					return []
				
				items = for row in rawResults.rows
					sourceID: row[0], socialNetwork: row[1], visitorCount: parseInt(row[2], 10), averageTimeOnPage: row[3], entranceRate: row[4]
				
				# Group items by social network. e.g. facebook.com & m.facebook.com will be grouped under 'Facebook'.
				itemsGroupedBySocialNetwork = _.groupBy items, (row) ->
					row.socialNetwork
				
				nonSocialNetworkID = "(not set)"
				nonSocialSources = itemsGroupedBySocialNetwork[nonSocialNetworkID]
				onlySocialSources = _.omit(itemsGroupedBySocialNetwork, nonSocialNetworkID)
				
				itemsSummingSocialNetworks = for socialNetworkID, entries of onlySocialSources
					baseEntry = entries[0]
					baseEntry.visitorCount = _.reduce entries, (tally, entry) ->
						tally + entry.visitorCount
					, 0
					baseEntry.allSourceIDs = _.pluck(entries, 'sourceID')
					
					baseEntry
				
				
				items = itemsSummingSocialNetworks.concat(nonSocialSources)
				items = _.sortBy items, (sourceInfo) ->
					-sourceInfo.visitorCount
				
				return items
		
		
		###
		topSearchSources: {
			query: function() {
				return owner.combineQueries(owner.queryForBetweenSetDates(), {
					'dimensions': 'ga:source',
					'metrics': 'ga:visitors',
					'sort': '-ga:visitors',
					'filters': 'ga:medium==organic',
					'max-results': 5
				});
			},
			processResults: function(rawResults) {
				return _.map(rawResults.rows, function(row) {
					return {sourceID: row[0], socialNetwork: row[1], visitorCount: parseInt(row[2], 10)};
				});
			}
		}
		###
		
		
		topKeywords:
			query: ->
				return @combineQueries @queryForBetweenSetDates(), {
					'dimensions': 'ga:keyword',
					'metrics': 'ga:visitors',
					'sort': '-ga:visitors',
					'filters': 'ga:keyword!=(not set);ga:keyword!=(not provided)',
					'max-results': 5
				}
			
			processResults: (rawResults) ->
				###
				return for row in rawResults.rows {
					keyword: row[0],
					visitorCount: parseInt row[1], 10
				}
				###
				
		
		
		newAndReturningVisitors:
			query: ->
				@combineQueries @queryForBetweenSetDates(), {
					'dimensions': 'ga:visitorType',
					'metrics': 'ga:visits',
					'sort': 'ga:visitorType'
				}
			
			processResults: (rawResults) ->
				unless rawResults?.rows?
					return null
				
				newVisitorsCount = _.findWhere rawResults.rows, ["New Visitor"]
				returningVisitorsCount = _.findWhere rawResults.rows, ["Returning Visitor"]
				
				newVisitorsCount = if newVisitorsCount then parseInt newVisitorsCount[1] else 0
				returningVisitorsCount = if returningVisitorsCount then parseInt returningVisitorsCount[1] else 0
				totalVisitorsCount = newVisitorsCount + returningVisitorsCount
				
				newVisitorsFraction = returningVisitorsFraction = 0
				if totalVisitorsCount > 0
					newVisitorsFraction = newVisitorsCount / totalVisitorsCount
					returningVisitorsFraction = returningVisitorsCount / totalVisitorsCount
				
				{newVisitors: newVisitorsFraction, returningVisitors: returningVisitorsFraction}
		
		
		totalUniqueVisitors:
			query: ->
				@combineQueries @queryForTotalAcrossAllTime(),
					'metrics': 'ga:visitors'
			
			processResults: (rawResults) ->
				return rawResults.rows[0][0]
		
		
		totalPageViews:
			query: ->
				return @combineQueries @queryForTotalAcrossAllTime(), {
					'metrics': 'ga:pageviews'
				}
			
			processResults: (rawResults) ->
				return rawResults.rows[0][0]
		
		
		engagement:
			query: ->
				@combineQueries @queryForBetweenSetDates(), {
					#'dimensions': 'ga:visitorType',
					#'metrics': 'ga:visits,ga:avgTimeOnPage, ga:entranceRate, ga:pageviewsPerVisit'
					'metrics': 'ga:avgTimeOnPage, ga:entranceRate'
				}
			
			processResults: (rawResults) ->
				return rawResults
		
		
		averageTimeOnPage:
			reliesOn: "engagement",
			processResults: (rawResults) ->
				if rawResults.totalResults is 0
					return null
				
				return rawResults.rows[0][0]
		
		
		entranceRate:
			reliesOn: "engagement",
			processResults: (rawResults) ->
				return rawResults.rows[0][1]

		
	allStatIDs: (statID) =>
		if statID
			return @statIDsToHandlers[statID]
		
		allStatIDs = {}
		for statID, handler in @statIDsToHandlers
			allStatIDs[statID] = true
		
		return allStatIDs
	
	
	@displayDateForGoogleAPI: (date, options) ->
		d = date.getDate()
		m = date.getMonth() + 1
		y = date.getFullYear()
		
		divider = if options?.isInResults then '' else '-'
		
		return [y, (if m<=9 then '0' + m else m), (if d <= 9 then '0' + d else d)].join divider
	