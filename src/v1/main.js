/*!
  Copyright 2013 Patrick Smith
*/
"Copyright 2013 Patrick Smith";

var App = {};
_.extend(App, Backbone.Events);

var $ = jQuery;
var $d = $(document);

window.hoverlyticsProfileConfig = require('../-config/main-config-gel');


var googleClientAPIHasLoaded = false;
window.googleClientAPILoaded = function()
{
	console.log('callback googleClientAPILoaded');
	googleClientAPIHasLoaded = true;
	$d.trigger('googleClientAPILoaded');
	$d.off('googleClientAPILoaded');
};

function addGoogleClientAPIReadyCallback(callback)
{
	if (googleClientAPIHasLoaded) {
		callback.call();
	}
	else {
		$d.on('googleClientAPILoaded', function() {
			callback.call();
		});
	}
}


function burntDisplayDurationForSeconds(seconds)
{
	var units = ["hours", "minutes", "seconds"];
	/*var unitInfo = {
		"minutes": 60,
		"seconds": 60
	};
	var unitShortFormatting = {
		"hours": ["", ":"],
		"minutes": ["", ":"]
	};
	var unitLongFormatting = {
		"hours": [" ", "h"],
		"minutes": [" ", "m"],
		"seconds": [" ", "s"]
	};*/
	var values = [];
	
	seconds = Math.floor(seconds); // Round to an integer value.
	
	/*var valuesReversed = [];
	var previousValue = seconds;
	_.each(_.rest(info).reverse(), function(unitInfo, index) {
		previousValue = Math.floor(previousValue / unitInfo.units);
		
		var magnitude = Math.floor(Math.log(unitInfo.units) / Math.LN10);
		var formattedValue = ("0000000000" + value).slice(-magnitude);
		
		valuesReversed.push(formattedValue);
	});*/
	
	var minutes = Math.floor(seconds / 60);
	if (minutes > 60) {
		var hours = Math.floor(minutes / 60);
		minutes -= (hours * 60);
		values.push(hours);
	}
	
	values.push(minutes);
	
	seconds -= (minutes * 60);
	values.push(seconds);
	
	
	var shortSeparators = [":", ":", ""];
	var longSeparators = ["h ", "m ", "s "];
	var separators = shortSeparators;
	
	var valuesOffset = 3 - values.length;
	
	var output = _.reduce(values, function(output, value, displayedIndex) {
		var formattedValue;
		if (displayedIndex > 0) {
			//var magnitude = Math.floor(Math.log(value) / Math.LN10);
			formattedValue = ("0000000000" + value).slice(-2);
		}
		else {
			formattedValue = "" + value;
		}
		
		displayedIndex += valuesOffset;
		return output + formattedValue + separators[displayedIndex];
	}, "");
	
	output = output.trim(" ");
	
	return output;
	
	/*var divider = ':';
		
	return [y, (m<=9 ? '0' + m : m), (d <= 9 ? '0' + d : d)].join(divider);*/
}

function burntDisplayTextForCount(number)
{
	var suffix = '';
	if (number >= 1000) { // Thousands or higher:
		number /= 1000.0;
		if (number >= 1000) { // Millions or higher:
			number /= 1000.0;
			suffix = 'M';
		}
		else {
			suffix = 'K';
		}
	}
	
	return burntDisplayNumberWithDecimalPlaces(number, 1) + suffix;
}

function burntDisplayNumberWithDecimalPlaces(number, numberOfPlaces)
{
	return (Math.round(number * 10.0) / 10.0);
}

function burntNumberGrowGradually(numberA, numberB, fraction, type)
{
	if (!type) {
		type = 'normal';
	}
	
	/*var chunk; // One chunk equals
	if (type === 'duration') {
		chunk = 60;
	}*/
	
	var totalDifference = numberB - numberA;
	var change = totalDifference * fraction;
	return numberA + change;
}

function ilURLDomainForSourceID(sourceID)
{
	if (sourceID.indexOf('.') !== -1) {
		return sourceID;
	}
	else {
		return sourceID+'.com';
	}
}

function ilFavIconImageURLForSourceID(sourceID)
{
	if (sourceID === "(direct)") {
		//return ((location.pathname.indexOf("/-hoverlytics-server/") !== -1) ? "https://hoverlytics-qawixu.backliftapp.com" : "") + "/app/images/direct-traffic-symbol.png";
		return "http://www.burntcaramel.com/-assets/images/direct-traffic-symbol.png";
	}
	
	var sourceURL = 'http://' + ilURLDomainForSourceID(sourceID);
	var imageURL = 'https://getfavicon.appspot.com/' + encodeURIComponent(sourceURL) + '?defaulticon=bluepng';
	return imageURL;
}


var Profile = Backbone.Model.extend({
	initialize: function() {
		this.set('hasLoaded', false);
		
		var now = new Date();
		var startDate = new Date();
		startDate.setDate(now.getDate() - 28 + 1);
		//startDate.setDate(now.getDate() - 14 + 1);
		//startDate.setDate(now.getDate() - 3 + 1);
		this.set({startDate: startDate, endDate: now});
		
		var self = this;
		addGoogleClientAPIReadyCallback(function() {
			self.googleClientAPIReady();
		});
	},
	
	googleClientAPIReady: function() {
		gapi.client.setApiKey(window.hoverlyticsProfileConfig.googleAPIKey);
		
		var self = this;
		window.setTimeout(function() {
			self.checkGoogleAuthorization();
		}, 1);
	},
	
	checkGoogleAuthorization: function(options) {
		var performAuthorization = (options && options.performAuthorization);
		//console.log('profile: checkGoogleAuthorization', window.hoverlyticsProfileConfig.googleClientID, window.hoverlyticsProfileConfig.googleAPIScopes);
		var self = this;
		gapi.auth.authorize({client_id: window.hoverlyticsProfileConfig.googleClientID, scope: window.hoverlyticsProfileConfig.googleAPIScopes, immediate: !performAuthorization}, function(authorizationResult) {
			self.handleGoogleAuthorizationResult(authorizationResult);
		});
	},
	
	performGoogleAuthorization: function()
	{
		this.checkGoogleAuthorization({performAuthorization: true});
	},
	
	handleGoogleAuthorizationResult: function(authorizationResult) {
		//console.log('profile: handleGoogleAuthorization result', authorizationResult);
		var self = this;
		if (authorizationResult) {
			gapi.client.load('analytics', 'v3', function() {
				//console.log('profile: analytics api loaded', self);
				self.set('isAuthorized', true);
			});
		} else {
			self.set('isAuthorized', false);
		}
	},
	
	requestListOfAccounts: function() {
		var self = this;
		gapi.client.analytics.management.profiles.list({
			accountId: "~all",
			webPropertyId: "~all"
		}).execute(function(accountsResults) {
			var accountsList = accountsResults.items;
			//console.log('ACCOUNTS LIST', accountsResults);
			self.set('accountsList', accountsList);
		});
	},
	
	requestResultsWithOptions: function(options) {
		if (!options) {
			options = {};
		}
		
		return new AnalyticsResults(_.extend(this.pick(['profileID', 'startDate', 'endDate']), options));
	}
});



var AnalyticsResults = Backbone.Model.extend({
	defaults: function() {
		return {
			"pageURL": null,
			"activeSourceID": null
		};
	},
	
	sourceShouldCombineStats: {
		"facebook.com": ["m.facebook.com"]
	}, 
	
	initialize: function() {
		this.statIDsToRawResults = {};
		this.reliedStatIDsToDerivedStatIDs = {};
		
		this.listenTo(this, 'change:pageURL', this.invalidateStats);
	},
	
	get: function(attribute) {
		return Backbone.Model.prototype.get.call(this, attribute) || void(this.requestValueForStatID(attribute));
	},
	
	requestValueForStatID: function(statID) {
		console.log('requestValueForStatID:', statID, googleClientAPIHasLoaded);
		if (googleClientAPIHasLoaded && this.allStatIDs(statID)) {
			return this.loadResultsForStatID(statID);
		}
		else {
			return null;
		}
	},
	
	loadResultsForStatID: function(requestedStatID) {
		//console.log('loadResultsForStatID:', requestedStatID);
		var statResults = this.statIDsToRawResults[requestedStatID];
		if (statResults && statResults.loading) {
			return statResults;
		}
		
		var statResults = {loading: true};
		this.statIDsToRawResults[requestedStatID] = statResults;
		
		var self = this;
		var requestInfo = self.requestInfoForStatID(requestedStatID);
		console.log('REQUEST INFO', requestedStatID, requestInfo);
		if (requestInfo.reliesOn) {
			var reliedStatID = requestInfo.reliesOn;
			
			if (!self.reliedStatIDsToDerivedStatIDs[reliedStatID]) {
				self.reliedStatIDsToDerivedStatIDs[reliedStatID] = [];
			}
			self.reliedStatIDsToDerivedStatIDs[reliedStatID].push(requestedStatID);
			//console.log('Derived stat', requestedStatID, 'relies on:', reliedStatID);
			
			var reliedStatResults = self.statIDsToRawResults[reliedStatID];
			if (!reliedStatResults) {
				//console.log('Relied stat needs loading', reliedStatID);
				self.loadResultsForStatID(reliedStatID);
			}
			else if (reliedStatResults.loaded) {
				//console.log('Relied stat needs is loaded', reliedStatID);
				self.processResultsForStatInfo(requestInfo, reliedStatResults.rawResults);
			}
		}
		else {
			var query = requestInfo.query(self);
			
			console.log('Load query', requestedStatID, query);
			console.time('Load query ' + requestedStatID);
			gapi.client.analytics.data.ga.get(query).execute(function(rawResults) {
				console.timeEnd('Load query ' + requestedStatID);
				
				self.processResultsForStatInfo(requestInfo, rawResults);
			});
		}
		
		return statResults;
	},
	
	processResultsForStatInfo: function(requestInfo, rawResults) {
		var statID = requestInfo.statID;
		
		if (!rawResults) {
			return false;
		}
		
		var processedResults;
		try
		{
			processedResults = requestInfo.resultsHandlers(rawResults);
		}
		catch (exception) {
			//console.log('Problem loading:', statID);
			processedResults = null;
		}
		
		if (processedResults === null) {
			return false;
		}
		
		//console.log('Got results', statID, rawResults, processedResults);
		this.statIDsToRawResults[statID] = {loaded: true, rawResults: rawResults};
		this.set(statID, processedResults);
		
		if (this.reliedStatIDsToDerivedStatIDs[statID]) {
			var self = this;
			//console.log('Processing derived stats', this.reliedStatIDsToDerivedStatIDs[statID]);
			_.each(this.reliedStatIDsToDerivedStatIDs[statID], function(derivedStatID) {
				self.processResultsForStatInfo(self.requestInfoForStatID(derivedStatID), rawResults);
			});
		}
	},
	
	invalidateStats: function() {
		var self = this;
		_.each(this.allStatIDs(), function(value, statID) {
			//console.log('INVALIDATE:', statID);
			self.unset(statID);
		});
		
		self.statIDsToRawResults = {};
	},
	
	baseQuery: function() {
		var query = {
			'ids': 'ga:'+this.get('profileID')
		};
		
		var pageURL = this.get('pageURL');
		if (pageURL) {
			//query['filters'] = ('ga:pagePath==' + pageURL);
			// Instead of matching just the exact URL, also match ones with a query or hash.
			// Regex from http://stackoverflow.com/a/13157996
			var regexEscapedPageURL = pageURL.replace(/[\-\[\]{}()*+?.,\\\^$|#\s]/g, "\\$&");
			query['filters'] = ('ga:pagePath=~^' + regexEscapedPageURL + '/?([?].*)?([#].*)?$');
		};
		
		var activeSourceID = this.get('activeSourceID');
		//console.log('BUILD QUERY activeSourceID:', activeSourceID);
		if (activeSourceID) {
			query = this.combineQueries(query, {
				'filters': 'ga:source==' + activeSourceID
			});
		}
		
		return query;
	},
	
	combineQueries: function() {
		var finalQuery = {};
		var filterList = [];
		
		_.each(arguments, function(query) {
			var basicQuery = _.omit(query, 'filters');
			_.extend(finalQuery, basicQuery);
			
			if (query['filters']) {
				filterList.push(query['filters']);
			}
		});
		
		if (filterList.length !== 0) {
			finalQuery['filters'] = filterList.join(';');
		}
		
		return finalQuery;
	},
	
	queryForBetweenSetDates: function() {
		return _.extend(this.baseQuery(), {
			'start-date': AnalyticsResults.displayDateForGoogleAPI(this.get('startDate')),
			'end-date': AnalyticsResults.displayDateForGoogleAPI(this.get('endDate')),
			'max-results': 50
		});
	},
	
	queryForToday: function() {
		//console.log('queryForBetweenSetDates:', this.get('startDate'));
		var displayedDate = AnalyticsResults.displayDateForGoogleAPI(new Date());
		return _.extend(this.baseQuery(), {
			'start-date': displayedDate,
			'end-date': displayedDate
		});
	},
	
	queryForTotalAcrossAllTime: function() {
		return _.extend(this.baseQuery(), {
			'start-date': '2005-01-01',
			'end-date': '2030-01-01',
			'max-results': 1
		});
	},
	
	requestInfoForStatID: function(statID) {
		var requestInfo = this.statIDsToHandlers[statID];
		requestInfo.statID = statID;
		
		return requestInfo;
	},
	
	statIDsToHandlers: {
		dailyUniqueVisitors: {
			query: function(owner) {
				return owner.combineQueries(owner.queryForBetweenSetDates(), {
					'dimensions': 'ga:date',
					'metrics': 'ga:visitors',
					'sort': 'ga:date',
				});
			},
			resultsHandlers: function(rawResults) {
				return _.map(rawResults.rows, function(row) {
					var dateCompressed = row[0];
					var year = parseInt(dateCompressed.substring(0, 4), 10);
					var month = parseInt(dateCompressed.substring(4, 6), 10);
					var day = parseInt(dateCompressed.substring(6, 8), 10);
					return {date: new Date(year, month - 1, day), visitorCount: parseInt(row[1], 10)};
				});
			}
		},
		
		/*todaysUniqueVisitors: {
			reliesOn: "dailyUniqueVisitors",
			resultsHandlers: function(rawResults) {
				var rowForCurrentDate = _.last(rawResults.rows);
				return rowForCurrentDate ? rowForCurrentDate[1] : null;
			}
		},*/
		
		todaysUniqueVisitors: {
			query: function(owner) {
				return owner.combineQueries(owner.queryForToday(), {
					'dimensions': 'ga:date',
					'metrics': 'ga:visitors',
					'max-results': 1
				});
			},
			resultsHandlers: function(rawResults) {
				return rawResults.rows[0][1];
			}
		},
		
		pastMonthVisitorsCount: {
			reliesOn: "dailyUniqueVisitors",
			resultsHandlers: function(rawResults) {
				var total = _.reduce(rawResults.rows, function(count, row) {
					return count + parseInt(row[1], 10);
				}, 0);
				return total;
			}
		},
		
		pastWeekVisitorsCount: {
			reliesOn: "dailyUniqueVisitors",
			resultsHandlers: function(rawResults) {
				return _.reduce(_.last(rawResults.rows, 7), function(count, row) {
					return count + parseInt(row[1], 10);
				}, 0);
			}
		},
		
		todaysTopSource: {
			query: function(owner) {
				return owner.combineQueries(owner.queryForToday(), {
					'dimensions': 'ga:source',
					'metrics': 'ga:visitors',
					'sort': '-ga:visitors',
					//'filters': 'ga:source!=(direct)', 
					'max-results': 1
				});
			},
			resultsHandlers: function(rawResults) {
				//console.log('TODAYSTOPSOURCE RESULTS', rawResults);
				var row = rawResults.rows[0];
				return {sourceID: row[0], visitorCount: parseInt(row[1], 10)};
			}
		},
		
		/*topSources: {
			query: function(owner) {
				return owner.combineQueries(owner.queryForBetweenSetDates(), {
					'dimensions': 'ga:source',
					'metrics': 'ga:visitors',
					'sort': '-ga:visitors',
					'max-results': 5
				});
			},
			resultsHandlers: function(rawResults) {
				return _.map(rawResults.rows, function(row) {
					return {sourceID: row[0], visitorCount: parseInt(row[1], 10)};
				});
			}
		},*/
		
		topSources: {
			query: function(owner) {
				return owner.combineQueries(owner.queryForBetweenSetDates(), {
					'dimensions': 'ga:source, ga:socialNetwork',
					'metrics': 'ga:visitors, ga:avgTimeOnPage, ga:entranceRate',
					'sort': '-ga:visitors',
					//'filters': 'ga:hasSocialSourceReferral==Yes',
					'max-results': 7
				});
			},
			resultsHandlers: function(rawResults) {
				//console.log('TOP SOCIAL SOURCES', rawResults.rows);
				var items = _.map(rawResults.rows, function(row) {
					return {sourceID: row[0], socialNetwork: row[1], visitorCount: parseInt(row[2], 10), averageTimeOnPage: row[3], entranceRate: row[4]};
				});
				
				// Group items by social network. e.g. facebook.com & m.facebook.com will be grouped under 'Facebook'.
				var itemsGroupedBySocialNetwork = _.groupBy(items, function(row) {
					return row.socialNetwork;
				});
				
				var nonSocialNetworkID = "(not set)";
				var nonSocialSources = itemsGroupedBySocialNetwork[nonSocialNetworkID];
				var onlySocialSources = _.omit(itemsGroupedBySocialNetwork, nonSocialNetworkID);
				
				//console.log(_.clone(itemsGroupedBySocialNetwork));
				var itemsSummingSocialNetworks = _.map(onlySocialSources, function(entries) {
					var baseEntry = entries[0];
					baseEntry.visitorCount = _.reduce(entries, function(memo, entry) {
						return memo + entry.visitorCount;
					}, 0);
					baseEntry.allSourceIDs = _.pluck(entries, "sourceID");
					
					return baseEntry;
				});
				
				items = itemsSummingSocialNetworks.concat(nonSocialSources);
				items = _.sortBy(items, function(sourceInfo) {
					return -sourceInfo.visitorCount;
				});
				
				return items;
			}
		},
		
		/*topSearchSources: {
			query: function(owner) {
				return owner.combineQueries(owner.queryForBetweenSetDates(), {
					'dimensions': 'ga:source',
					'metrics': 'ga:visitors',
					'sort': '-ga:visitors',
					'filters': 'ga:medium==organic',
					'max-results': 5
				});
			},
			resultsHandlers: function(rawResults) {
				return _.map(rawResults.rows, function(row) {
					return {sourceID: row[0], socialNetwork: row[1], visitorCount: parseInt(row[2], 10)};
				});
			}
		},*/
		
		topKeywords: {
			query: function(owner) {
				return owner.combineQueries(owner.queryForBetweenSetDates(), {
					'dimensions': 'ga:keyword',
					'metrics': 'ga:visitors',
					'sort': '-ga:visitors',
					'filters': 'ga:keyword!=(not set);ga:keyword!=(not provided)',
					'max-results': 5
				});
			},
			resultsHandlers: function(rawResults) {
				//console.log('TOP KEYWORDS', rawResults.rows);
				return _.map(rawResults.rows, function(row) {
					return {keyword: row[0], visitorCount: parseInt(row[1], 10)};
				});
			}
		},
		
		newAndReturningVisitors: {
			query: function(owner) {
				return owner.combineQueries(owner.queryForBetweenSetDates(), {
					'dimensions': 'ga:visitorType',
					'metrics': 'ga:visits',
					'sort': 'ga:visitorType'
				});
			},
			resultsHandlers: function(rawResults) {
				if (!rawResults.rows) {
					return null;
				}
				
				var newVisitorsCount = _.findWhere(rawResults.rows, ["New Visitor"]);
				var returningVisitorsCount = _.findWhere(rawResults.rows, ["Returning Visitor"]);
				
				newVisitorsCount = newVisitorsCount ? parseInt(newVisitorsCount[1]) : 0;
				returningVisitorsCount = returningVisitorsCount ? parseInt(returningVisitorsCount[1]) : 0;
				var totalVisitorsCount = newVisitorsCount + returningVisitorsCount;
				
				var newVisitorsFraction = 0, returningVisitorsFraction = 0;
				if (totalVisitorsCount > 0) {
					newVisitorsFraction = newVisitorsCount / totalVisitorsCount;
					returningVisitorsFraction = returningVisitorsCount / totalVisitorsCount;
				}
				
				return {newVisitors: newVisitorsFraction, returningVisitors: returningVisitorsFraction};
			}
		},
		
		totalUniqueVisitors: {
			query: function(owner) {
				return owner.combineQueries(owner.queryForTotalAcrossAllTime(), {
					'metrics': 'ga:visitors'
				});
			},
			resultsHandlers: function(rawResults) {
				return rawResults.rows[0][0];
			}
		},
		
		totalPageViews: {
			query: function(owner) {
				return owner.combineQueries(owner.queryForTotalAcrossAllTime(), {
					'metrics': 'ga:pageviews'
				});
			},
			resultsHandlers: function(rawResults) {
				return rawResults.rows[0][0];
			}
		},
		
		engagement: {
			query: function(owner) {
				return owner.combineQueries(owner.queryForBetweenSetDates(), {
					//'dimensions': 'ga:visitorType',
					//'metrics': 'ga:visits,ga:avgTimeOnPage, ga:entranceRate, ga:pageviewsPerVisit'
					'metrics': 'ga:avgTimeOnPage, ga:entranceRate'
				});
			},
			resultsHandlers: function(rawResults) {
				return rawResults;
			}
		},
		
		averageTimeOnPage: {
			reliesOn: "engagement",
			resultsHandlers: function(rawResults) {
				return rawResults.rows[0][0];
			}
			/*query: function(owner) {
				return owner.combineQueries(owner.queryForBetweenSetDates(), {
					'metrics': 'ga:avgTimeOnPage',
					'max-results': 1
				});
			},*/
		},
		
		entranceRate: {
			reliesOn: "engagement",
			resultsHandlers: function(rawResults) {
				return rawResults.rows[0][1];
			}
			/*query: function(owner) {
				return owner.combineQueries(owner.queryForBetweenSetDates(), {
					'metrics': 'ga:entranceRate',
					'max-results': 1
				});
			},
			resultsHandlers: function(rawResults) {
				return rawResults.rows[0][0];
			}*/
		}
	},
	
	allStatIDs: function(statID)
	{
		if (statID) {
			return this.statIDsToHandlers[statID];
		}
		
		var allStatIDs = {};
		_.each(this.statIDsToHandlers, function(hander, statID) {
			allStatIDs[statID] = true;
		});
		return allStatIDs;
	}
},
{
	displayDateForGoogleAPI: function(date, options) {
		var d = date.getDate();
		var m = date.getMonth() + 1;
		var y = date.getFullYear();
		
		var divider = (options && options.isInResults) ? '' : '-';
		
		return [y, (m<=9 ? '0' + m : m), (d <= 9 ? '0' + d : d)].join(divider);
	}
});


var ProfileView = Backbone.View.extend({
	el: '#profileDetails',
	
	events: {
		"change #profileIDInput": "changeProfileID",
		"click #authorizeButton": "clickedAuthorizationButton",
		"click #accountsList li": "clickedAccountsListItem"
	},
	
	initialize: function() {
		this.listenTo(this.model, 'change:profileID', this.profileIDChanged);
		this.listenTo(this.model, 'change:isAuthorized', this.isAuthorizedChanged);
		this.listenTo(this.model, 'change:accountsList', this.displayListOfAccounts);
		
		var instructionsHTML = JST['instructions-log-in']();
		this.$('#logInToAccountInstructions').html(instructionsHTML);
	},
	
	displayListOfAccounts: function()
	{
		var html = JST['account-choices-list']({profile: this.model});
		this.$('#accountChoices').html(html);
	},
	
	/* Model Events */
	
	profileIDChanged: function(profile, value, options) {
		//console.log('model profile id changed:', value);
		this.$('#profileIDInput').val(value);
	},
	
	isAuthorizedChanged: function(profile, isAuthorized) {
		this.$el.toggleClass('authorized', isAuthorized);
		
		if (isAuthorized && !this.model.get('profileID')) {
			this.model.requestListOfAccounts();
		}
	},
	
	/* View Events */
	
	changeProfileID: function(event) {
		var enteredProfileID = this.$('#profileIDInput').val();
		//console.log('entered profile id changed:', enteredProfileID);
		this.model.set('profileID', enteredProfileID);
	},
	
	clickedAuthorizationButton: function(event) {
		event.preventDefault();
		
		this.model.performGoogleAuthorization();
	},
	
	clickedAccountsListItem: function(event) {
		event.preventDefault();
		
		var listItem = $(event.target).closest('li');
		var profileID = listItem.data('profileID');
		//console.log('selected profile id:', profileID);
		this.model.set('profileID', profileID);
		
		this.trigger('newProfileIDSelected', this, profileID);
	}
});


//!PAGE RESULTS VIEW


var PageResultsView = Backbone.View.extend({
	el: '#pageResults',
	
	currentPageURL: null,
	pageURLsToResults: {},
	sectionsInfo: {
		"topKeywords": {
			"resultsEvents": "change:topKeywords",
			"el": "#topKeywords",
			"template": "stats-top-keywords",
			"adjustsHeight": true
		}
	},
	
	events: {
		"click #sectionOptions a[data-section-i-d]": "clickedToggleSectionButton",
		"click #topSourcesList li": "clickedTopSourcesItem"
	},
	
	initialize: function(options)
	{
		var self = this;
		var profile = this.profile = options.profile;
		
		this.listenTo(profile, 'change:isAuthorized', this.profileIsAuthorizedChanged);
		//this.listenTo(profile, 'change:profileID', this.displayInputInfo);
		this.listenTo(profile, 'change:profileID', this.profileIDChanged);
		
		this.listenTo(this, 'change:currentPageURL', this.pageURLChanged);
		
		
		var instructionsHTML = JST['instructions-encourage-hover']();
		this.$('#encourageInstructions').html(instructionsHTML);
		
		
		this.activeOptions = {};
		
		
		addGoogleClientAPIReadyCallback(function() {
			self.render();
		});
	},
	
	setUpResults: function()
	{
		var self = this;
		
		var pageURL = this.currentPageURL;
		if (!pageURL) {
			return;
		}
		
		
		if (this.results) {
			this.stopListening(this.results);
			
			this.results = null;
			//this.activeOptions = {};
		}
		
		
		var results;
		if (this.pageURLsToResults[pageURL]) {
			results = this.pageURLsToResults[pageURL];
		}
		else {
			results = this.profile.requestResultsWithOptions({pageURL: pageURL});
			this.pageURLsToResults[pageURL] = results;
		}
		
		// Check if All Times View has changed, if it has then reload all stats.
		
		this.results = results;
		
		this.listenTo(results, 'change:todaysUniqueVisitors change:todaysTopSource', this.displayTodaysNumbers);
		this.listenTo(results, 'change:newAndReturningVisitors', this.displayVisitorLoyalty);
		this.listenTo(results, 'change:totalPageViews change:averageTimeOnPage change:entranceRate', this.displayTotalNumbers);
		this.listenTo(results, 'change:dailyUniqueVisitors change:pastMonthVisitorsCount change:pastWeekVisitorsCount', _.throttle(this.displayDailyUniqueVisitorsGraph, 50)); 
		this.listenTo(results, 'change:topSources', this.displayTopSources);
		
		
		_.each(this.sectionsInfo, function(sectionInfo, sectionID) {
			if (sectionInfo["resultsEvents"]) {
				self.listenTo(results, sectionInfo["resultsEvents"], function() {
					if (!sectionInfo.isEnabled) {
						return;
					}
					
					self.needsRender();
				});
			}
		});
		
		
		this.setUpResultsForActiveSource();
	},
	
	setUpResultsForActiveSource: function()
	{
		this.resultsForActiveSource = null;
		
		var pageURL = this.currentPageURL;
		if (!pageURL) {
			return;
		}
		
		var results = null;
		if (this.activeOptions.topSourceID) {
			var activeSourceID = this.activeOptions.topSourceID;
			results = this.profile.requestResultsWithOptions({pageURL: pageURL, activeSourceID: activeSourceID});
		}
		
		if (results) {
			this.resultsForActiveSource = results;
			
			this.listenTo(results, 'change:dailyUniqueVisitors', _.throttle(this.displayDailyUniqueVisitorsGraph, 50)); 
		}
	},
	
	setUpHeight: function()
	{
		var height = this.height = 384;
		this.trigger('change:height', this, height);
	},
	
	setEnabledSections: function(enabledSections)
	{
		var self = this;
		
		enabledSections = _.pick(enabledSections, _.keys(this.sectionsInfo));
		
		_.each(enabledSections, function(isEnabled, sectionID) {
			//console.log('CHNAGE SECTION is enabled', isEnabled);
			//self.sectionsInfo[sectionID].isEnabled = isEnabled;
			self.adjustSection(sectionID, {show: isEnabled});
		});
		
		//this.needsRender();
	},
	
	displayVisibleSections: function()
	{
		var self = this;
		
		_.each(this.sectionsInfo, function(sectionInfo, sectionID) {
			//console.log('DISPLAY SECTION:', sectionID);
			//console.log('RENDER SECTION', sectionInfo.isEnabled);
			if (!sectionInfo.isEnabled) {
				return;
			}
			
			if (sectionInfo["template"]) {
				// Automated use of JST.
				var sectionElement = self.$(sectionInfo["el"]);
				var HTML = JST[sectionInfo["template"]]({results: self.results, activeOptions: self.activeOptions});
				sectionElement.html(HTML);
			}
			else if (sectionInfo["display"]) {
				// Call display function.
				self[sectionInfo["display"]].call(self);
			}
			
			self.adjustSection(sectionID);
		});
	},
	
	render: function()
	{
		var self = this;
		
		if (this.profile.get('profileID') && this.results != null) {
			this.displayTodaysNumbers();
			this.displayVisitorLoyalty();
			this.displayTotalNumbers();
			this.displayDailyUniqueVisitorsGraph();
			this.displayTopSources();
			
			this.displayVisibleSections();
		}
		
		this.$("#sectionOptions a[data-section-i-d]").each(function() {
			var button = jQuery(this);
			var sectionID = button.data('sectionID');
			var isEnabled = self.sectionIsEnabled(sectionID);
			button.toggleClass('selected', isEnabled);
		});
		
		this.needsRenderFlag = false;
	},
	
	needsRender: function()
	{
		if (!this.needsRenderFlag) {
			this.needsRenderFlag = true;
			_.defer(_.bind(this.render, this));
		}
	},
	
	changeHeight: function(difference)
	{
		this.height += difference;
		this.trigger('change:height', this, this.height);
	},
	
	sectionIsEnabled: function(sectionID)
	{
		var sectionInfo = this.sectionsInfo[sectionID];
		return (sectionInfo.isEnabled != null) ? (sectionInfo.isEnabled) : false;
	},
	
	adjustSection: function(sectionID, options)
	{//console.log('ADJUST SECTION', sectionID, options);
		var sectionInfo = this.sectionsInfo[sectionID];
		if (!sectionInfo.adjustsHeight) {
			return;
		}
		
		var sectionElement = self.$(sectionInfo["el"]);
		
		var previousHeight = sectionElement.data('previousHeight') || 0;
		var newHeight = null;
		
		if (options && options.toggle) {
			var currentlyEnabled = this.sectionIsEnabled(sectionID);
			options.show = !currentlyEnabled;
		}
		
		if (options && options.show != null) {
			var show = options.show;
			sectionInfo.isEnabled = show;
			sectionElement.toggle(show);
			//console.log('SHOWING SECTION:', sectionElement.is(':visible'));
			newHeight = show ? sectionElement.outerHeight() : 0;
			
			this.trigger('sectionIsEnabledChanged', this, sectionID, show);
			
			this.needsRender();
		}
		else {
			newHeight = sectionElement.outerHeight();
		}
		
		//console.log('CHANGING HEIGHT FOR SECTION:', newHeight, previousHeight);
		
		if (newHeight != null && newHeight != previousHeight) {
			this.changeHeight(newHeight - previousHeight);
			sectionElement.data('previousHeight', newHeight);
		}
	},
	
	displayTodaysNumbers: function()
	{
		var pageResultsHTML = JST['stats-todays-numbers']({results: this.results, activeOptions: this.activeOptions});
		this.$('#todaysNumbers').html(pageResultsHTML);
	},
	
	displayVisitorLoyalty: function()
	{
		var pageResultsHTML = JST['stats-visitor-loyalty']({results: this.results, activeOptions: this.activeOptions});
		this.$('#visitorLoyalty').html(pageResultsHTML);
	},
	
	displayTotalNumbers: function()
	{
		var pageResultsHTML = JST['stats-total-numbers']({results: this.results, activeOptions: this.activeOptions});
		this.$('#totalNumbers').html(pageResultsHTML);
	},
	
	displayDailyUniqueVisitorsGraph: function()
	{
		//console.log('DISPLAY GRAPH');
		var dailyUniqueVisitors = this.results.get('dailyUniqueVisitors');
		if (!dailyUniqueVisitors) {
			return;
		}
		
		var visitorCountInDataInfo = function(dataInfo)
		{
			return dataInfo.visitorCount;
		};
		
		var maxValue = _.max(dailyUniqueVisitors, visitorCountInDataInfo).visitorCount;
		var minValue = _.min(dailyUniqueVisitors, visitorCountInDataInfo).visitorCount;
		var valueRange = maxValue - minValue;
		var rangeExponent = Math.floor(Math.log(valueRange) / Math.LN10);
		var baseValue = Math.pow(10, rangeExponent);
		var maxOnChart = Math.ceil(maxValue / baseValue) * baseValue;
		var minOnChart = Math.floor(minValue / baseValue) * baseValue;
		//console.log('maxValue', maxValue, 'minValue', minValue, 'valueRange', valueRange);
		//console.log('rangeExponent', rangeExponent, 'baseValue', baseValue);
		//console.log('maxOnChart', maxOnChart, 'minOnChart', minOnChart);
		
		var baseChartOptions = {
			max_x_labels: 3,
			y_axis_scale: [0, maxOnChart],
			x_label_size: 10,
			y_label_size: 10,
			label_max: false,
			label_min: false,
			font_family: "Verdana, sans-serif",
			dot_size: 4,
			dot_stroke_size: 0,
			/*area_opacity: 0.6666,*/
			area_opacity: 0.92,
			smoothing: 0.1
		};
		
		var sparklineChartOptions = {
			x_padding: 0,
			y_padding: 0,
			show_x_labels: false,
			show_y_labels: false,
			dot_size: 0,
			smoothing: 0,
			/*line_width: 3,*/
			line_width: 1,
			//area_color: null,
			y_axis_scale: [0, maxOnChart]
		};
		
		var earlierChartOptions = {
			line_color: '#008394',
			dot_color: '#008394',
			area_color: '#008394'
		};
		
		var pastWeekChartOptions = {
			line_color: '#0086c3',
			dot_color: 'white',
			area_color: '#0086c3'
		};
		
		var activeSourceChartOptions = {
			line_color: 'white',
			line_width: 0.333,
			area_color: '#fa583f',
			area_opacity: 1.0
		};
		
		
		var earlierData = _.initial(dailyUniqueVisitors, 6);
		var pastWeekData = _.last(dailyUniqueVisitors, 7);
		
		var monthSparkline = this.$('#monthSparkline');
		var weekSparkline = this.$('#weekSparkline');
		
		this.setUpChart(monthSparkline);
		this.setUpChart(weekSparkline);
		
		this.displayChart(monthSparkline, earlierData, _.extend({}, baseChartOptions, earlierChartOptions, sparklineChartOptions));
		this.displayChart(weekSparkline, pastWeekData, _.extend({}, baseChartOptions, pastWeekChartOptions, sparklineChartOptions));
		
		
		if (this.resultsForActiveSource) {
			var activeSourceDailyUniqueVisitors = this.resultsForActiveSource.get('dailyUniqueVisitors');
			if (activeSourceDailyUniqueVisitors) {
				var activeSourcePastMonthData = _.initial(activeSourceDailyUniqueVisitors, 6);
				var activeSourcePastWeekData = _.last(activeSourceDailyUniqueVisitors, 7);
				// Month
				var activeSourceMonthSparkline = jQuery('<div></div>', {'id': 'activeSourceWeekSparkline', 'class': 'sparkline'}).css({position: 'absolute', bottom: 0});
				activeSourceMonthSparkline.appendTo(monthSparkline);
				this.setUpChart(activeSourceMonthSparkline);
				this.displayChart(activeSourceMonthSparkline, activeSourcePastMonthData, _.extend({}, baseChartOptions, sparklineChartOptions, activeSourceChartOptions));
				// Week
				var activeSourceWeekSparkline = jQuery('<div></div>', {'id': 'activeSourceMonthSparkline', 'class': 'sparkline'}).css({position: 'absolute', bottom: 0});
				activeSourceWeekSparkline.appendTo(weekSparkline);
				this.setUpChart(activeSourceWeekSparkline);
				this.displayChart(activeSourceWeekSparkline, activeSourcePastWeekData, _.extend({}, baseChartOptions, sparklineChartOptions, activeSourceChartOptions));
			}
		}
		
		
		var captionHTML = JST['stats-chart-captions']({results: this.results, activeOptions: this.activeOptions});
		var captions = $('<div></div>').html(captionHTML);
		
		monthSparkline.append(captions.find('#pastMonthVisitorsChartCaption'));
		weekSparkline.append(captions.find('#pastWeekVisitorsChartCaption')); 
	},
	
	setUpChart: function(graphHolder)
	{
		graphHolder.width(graphHolder.width()).height(graphHolder.height());
		graphHolder.empty();
	},
	
	displayChart: function(graphHolder, data, options)
	{
		var chart = new Charts.LineChart(graphHolder.get(0), options);
		
		chart.add_line({
			data: _.map(data, function(dataInfo) {
				return [dataInfo.date, dataInfo.visitorCount];
			})
		});
		
		chart.draw();
	},
	
	displayTopSources: function()
	{
		var pageResultsHTML = JST['stats-top-sources']({results: this.results, activeOptions: this.activeOptions});
		this.$('#topSources').html(pageResultsHTML);
	},
	
	
	changeActiveOptions: function(changes)
	{
		_.extend(this.activeOptions, changes);
		
		if (!_.isUndefined(changes.topSourceID)) {
			this.setUpResultsForActiveSource();
		}
	},
	
	/* Model Events */
	
	profileIsAuthorizedChanged: function(profile, isAuthorized)
	{
		//console.log('profileIsAuthorizedChanged', isAuthorized);
		if (isAuthorized && this.profile.get('profileID')) {
			//this.setUpResults();
			//this.render();
		}
	},
	
	profileIDChanged: function(profile, profileID)
	{
		this.setUpResults();
		this.render();
	},
	
	pageURLChanged: function()
	{
		console.log('PAGE URL CHANGED');
		this.setUpResults();
		//console.log('CALLING RENDER');
		this.render();
	},
	
	chosenPageURLChanged: function(sender, pageURL)
	{
		var URLPath;
		var URLComponents = pageURL.split('//');
		//console.log('URL COMPONENTS', URLComponents);
		if (URLComponents.length > 1) {
			URLPath = URLComponents[1]; // Part after the :// ie. domain+path+query+hash
			URLPath = URLPath.split('#')[0]; // Now just domain+path+query
			URLPath = '/' + _.rest(URLComponents[1].split('/')).join('/'); // Reduce to just path+query
		}
		else {
			URLPath = pageURL;
		}
		
		//console.log('chosenPageURLChanged:', URLPath);
		//this.results.set('pageURL', URLPath);
		
		//this.set('pageURL', URLPath);
		this.currentPageURL = URLPath;
		this.trigger('change:currentPageURL', this, URLPath);
	},
	
	clickedToggleSectionButton: function(event)
	{
		var button = jQuery(event.target);
		var sectionID = button.data('sectionID');
		
		this.adjustSection(sectionID, {toggle: true});
	},
	
	clickedTopSourcesItem: function(event)
	{
		var button = jQuery(event.target);
		var sourceID = button.data('sourceID');
		
		if (this.activeOptions.topSourceID != sourceID) {
			this.changeActiveOptions({topSourceID: sourceID});
		}
		else {
			this.changeActiveOptions({topSourceID: null});
		}
		
		this.needsRender();
	}
});



/*var CurrentUser = Backbone.Model.extend({
	url: '/backlift/auth/currentuser'
});*/


_.extend(App, {
	/*currentUser: null,*/
	
	init: function()
	{
		//console.log('HOVERLYTICS LOAD');
		var profile = this.profile = new Profile();
		this.listenTo(profile, 'change:profileID', this.profileIDChanged);
		this.listenTo(profile, 'change:isAuthorized', this.isAuthorizedChanged);
		
		//this.loadUser();
		
		this.setupSourceCommunication();
		
		this.setupViews();
		
		
		var isAuthorized = profile.get('isAuthorized');
		//console.log('CHECKING IS AUTHORIZED', isAuthorized);
		if (isAuthorized || isAuthorized === false) {
			//console.log('TRIGGER IS AUTHORIZED', isAuthorized);
			profile.trigger('change:isAuthorized', isAuthorized);
		}
	},
	
	setupSourceCommunication: function()
	{
		if (location.hash && location.hash.length > 1) {
			var info = $.parseJSON(decodeURIComponent(location.hash.substring(1)));
			var sourceProxyURL = info.sourceProxyURL;
			//console.log('SOURCE PROXY URL', sourceProxyURL);
			
			var sourceProxy = new Porthole.WindowProxy(sourceProxyURL);
			sourceProxy.addEventListener(_.bind(this.receivedMessageFromSource, this));
			this.sourceProxy = sourceProxy;
			
			
			if (info.googleAnalyticsProfileID) {
				//console.log('googleAnalyticsProfileID', info.googleAnalyticsProfileID);
				this.profile.set('profileID', info.googleAnalyticsProfileID);
			}
			else {
				this.profileIDChanged(this.profile, null);
			}
		}
	},
	
	setupViews: function()
	{
		var profile = this.profile;
		var profileView = this.profileView = new ProfileView({model: profile});
		this.listenTo(profileView, 'newProfileIDSelected', this.newProfileIDSelected);
		
		var pageResultsView = this.pageResultsView = new PageResultsView({profile: profile});
		this.listenTo(pageResultsView, 'change:height', this.pageResultsViewHeightChanged);
		pageResultsView.setUpHeight();
		
		this.sourceProxy.post({viewsReady: true});
		
		this.listenTo(pageResultsView, 'sectionIsEnabledChanged', this.sectionIsEnabledChanged);
	},
	
	receivedMessageFromSource: function(message)
	{
		console.log('RECEIVED MESSAGE FROM SOURCE', message, message.data, message.source);
		if (!message || !message.data) {
			return;
		}
		
		if (message.data.changePageURL) {
			this.changeChosenPageURL(message.data.changePageURL);
		}
		else if (message.data.enabledSections) {
			var enabledSections = message.data.enabledSections;
			//console.log('received enabledSections', enabledSections);
			this.pageResultsView.setEnabledSections(enabledSections);
		}
	},
	
	/*loadUser: function()
	{
		var thisApp = this;
		var currentUser = new CurrentUser();
		currentUser.fetch({
			success: function(currentUser) {
				thisApp.userDidLoad(currentUser);
			},
			error: function(currentUser) {
				// Need to log in!
				thisApp.currentUser = null;
			}
		});
	},
	
	userDidLoad: function(currentUser)
	{
		this.currentUser = currentUser;
		$('body').addClass('hasLoggedInUser');
	},
	
	v: function()
	{
		if (!this.currentUser)
			return;
		
		var currentUser = this.currentUser;
		var googleAnalyticsProfileID = currentUser.get('googleAnalyticsProfileID');
		
		googleAnalyticsProfileID = null;
		
		if (googleAnalyticsProfileID) {
			this.profile.set('profileID', googleAnalyticsProfileID);
			
			$('body').addClass('hasAnalyticsProfile');
		}
		else {
			$('body').addClass('needsAnalyticsProfile');
		}
	},
	*/
	
	changeChosenPageURL: function(pageURL)
	{
		this.pageResultsView.chosenPageURLChanged(this, pageURL);
		
		$('body').addClass('hasChosenPage');
	},
	
	profileIDChanged: function(profile, profileID)
	{
		$('body').toggleClass('hasAnalyticsProfile', profileID != null).toggleClass('needsAnalyticsProfile', profileID == null);
		
		if (profileID == null) {
			this.needsUserAttention();
		}
	},
	
	newProfileIDSelected: function(profile, profileID)
	{
		/*if (this.currentUser) {
			var currentUser = this.currentUser;
			currentUser.set('googleAnalyticsProfileID', profileID);
			currentUser.save();
		}*/
		
		this.sourceProxy.post({newProfileIDSelected: profileID});
	},
	
	pageResultsViewHeightChanged: function(pageResultsView, newHeight)
	{
		this.sourceProxy.post({changeHeight: newHeight});
	},
	
	sectionIsEnabledChanged: function(pageResultsView, sectionID, isEnabled)
	{
		this.sourceProxy.post({sectionIsEnabledChanged: {sectionID: sectionID, isEnabled: isEnabled}});
	},
	
	needsUserAttention: function()
	{
		this.sourceProxy.post({needsUser: true});
	},
	
	isAuthorizedChanged: function(profile, isAuthorized)
	{
		$('body').toggleClass('authorized', isAuthorized).toggleClass('needsAuthorization', !isAuthorized);
		
		if (!isAuthorized) {
			this.needsUserAttention();
		}
	}
});


$(function() {
	App.init();
});