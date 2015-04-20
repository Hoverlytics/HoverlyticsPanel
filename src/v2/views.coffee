"Copyright 2013 Patrick Smith"

root = exports ? this


root.garnishDurationWithSeconds = (seconds) ->
	units = ["hours", "minutes", "seconds"]
	###
	unitInfo = {
		"minutes": 60,
		"seconds": 60
	}
	unitShortFormatting = {
		"hours": ["", ":"],
		"minutes": ["", ":"]
	}
	unitLongFormatting = {
		"hours": [" ", "h"],
		"minutes": [" ", "m"],
		"seconds": [" ", "s"]
	}
	###
	values = []
	
	seconds = Math.floor seconds # Round to an integer value.
	
	###
	valuesReversed = []
	previousValue = seconds
	_.each(_.rest(info).reverse(), function(unitInfo, index) {
		previousValue = Math.floor(previousValue / unitInfo.units)
		
		magnitude = Math.floor(Math.log(unitInfo.units) / Math.LN10)
		formattedValue = ("0000000000" + value).slice(-magnitude)
		
		valuesReversed.push(formattedValue)
	})
	###
	
	minutes = Math.floor seconds / 60
	if minutes > 60
		hours = Math.floor minutes / 60
		minutes -= hours * 60
		values.push hours
	
	values.push minutes
	
	seconds -= minutes * 60
	values.push seconds
	
	
	shortSeparators = [":", ":", ""]
	longSeparators = ["h ", "m ", "s "]
	separators = shortSeparators
	
	valuesOffset = 3 - values.length
	
	output = _.reduce values, (output, value, displayedIndex) ->
		if displayedIndex > 0
			#magnitude = Math.floor(Math.log(value) / Math.LN10)
			formattedValue = ("0000000000" + value).slice(-2)
		else
			formattedValue = "" + value
		
		displayedIndex += valuesOffset
		return output + formattedValue + separators[displayedIndex]
	, ""
	
	output = output.trim " "
	
	return output
	
	###
	divider = ':'
		
	return [y, (m<=9 ? '0' + m : m), (d <= 9 ? '0' + d : d)].join(divider)
	###


root.garnishCount = (number) ->
	suffix = ''
	if number >= 1000 # Thousands or higher:
		number /= 1000.0
		if number >= 1000 # Millions or higher:
			number /= 1000.0
			suffix = 'M'
		else
			suffix = 'K'
	
	return root.garnishNumberWithDecimalPlaces(number, 1) + suffix


root.garnishNumberWithDecimalPlaces = (number, numberOfPlaces = 1) ->
	decimalFactor = Math.pow 10, numberOfPlaces
	return Math.round(number * decimalFactor) / decimalFactor


root.burntNumberGrowGradually = (numberA, numberB, fraction, type = 'normal') ->
	###
	# One chunk equals
	if type is 'duration'
		chunk = 60
	###
	
	totalDifference = numberB - numberA
	change = totalDifference * fraction
	return numberA + change


root.burntURLDomainForSourceID = (sourceID) ->
	if (sourceID.indexOf '.') isnt -1
		return sourceID
	else
		return "#{sourceID}.com"


root.burntFavIconImageURLForSourceID = (sourceID) ->
	if sourceID is '(direct)'
		#return ((location.pathname.indexOf("/-hoverlytics-server/") !== -1) ? "https://hoverlytics-qawixu.backliftapp.com" : "") + "/app/images/direct-traffic-symbol.png"
		#return "http://www.burntcaramel.com/-assets/images/direct-traffic-symbol.png"
		return '/panel/v2/images/direct-traffic-symbol.png'
	
	sourceURL = 'http://' + root.burntURLDomainForSourceID(sourceID)
	imageURL = 'https://getfavicon.appspot.com/' + encodeURIComponent(sourceURL) + '?defaulticon=bluepng'
	return imageURL


class root.ProfileView extends Backbone.View
	el: '#profileDetails'
	
	events: {
		'change #profileIDInput': 'changeProfileID'
		'click #authorizeButton': 'clickedAuthorizationButton'
		'click #accountsList li': 'clickedAccountsListItem'
	}
	
	initialize: ->
		@listenTo(@model, 'change:profileID', @profileIDChanged)
		@listenTo(@model, 'change:isAuthorized', @isAuthorizedChanged)
		@listenTo(@model, 'change:accountsList', @displayListOfAccounts)
		
		instructionsHTML = JST['instructions-log-in']()
		@$('#logInToAccountInstructions').html(instructionsHTML)
		
		return
	
	
	# Model Events
	
	profileIDChanged: (profile, value, options) =>
		#console.log 'model profile id changed:', value
		@$('#profileIDInput').val(value)
	
	
	isAuthorizedChanged: (profile, isAuthorized) =>
		#console.log('isAuthorizedChanged', isAuthorized)
		@$el.toggleClass('authorized', isAuthorized)
		###
		if isAuthorized && !@model.get('profileID')
			@model.requestListOfAccounts()
		###
	
	# View Events
	
	displayListOfAccounts: =>
		#console.log('accountsList', @model.get('accountsList'))
		html = JST['account-choices-list'](profile: @model)
		@$('#accountChoices').html(html)
	
	
	changeProfileID: (event) =>
		enteredProfileID = @$('#profileIDInput').val()
		#console.log('entered profile id changed:', enteredProfileID)
		@model.set('profileID', enteredProfileID)
	
	
	clickedAuthorizationButton: (event) =>
		event.preventDefault()
		
		@model.performGoogleAuthorization()
	
	
	clickedAccountsListItem: (event) =>
		#console.log('clickedAccountsListItem')
		event.preventDefault()
		
		listItem = $(event.target).closest('li')
		profileID = listItem.data('profileID')
		#console.log 'selected profile id:', profileID
		@model.set('profileID', profileID)
		
		@trigger('newProfileIDSelected', this, profileID)
	


class root.PageResultsView extends Backbone.View
	el: '#pageResults'
	baseHeight: 434
	currentPageURL: null
	
	sectionsInfo:
		topKeywords:
			resultsEvents: "change:topKeywords"
			el: "#topKeywords"
			template: "stats-top-keywords"
			adjustsHeight: true
	
	events: {
		'click #sectionOptions a[data-section-i-d]': 'clickedToggleSectionButton'
		'click #topSourcesList li': 'clickedTopSourcesItem'
		'click #newAndReturningVisitors': 'clickedNewVsReturningItem'
	}
	
	initialize: (options) ->
		@pageURLsToResults = {}
		@activeOptions = {}
		
		profile = @profile = options.profile
		
		@listenTo(profile, 'change:isAuthorized', @profileIsAuthorizedChanged)
		#@listenTo profile, 'change:profileID', @displayInputInfo
		@listenTo(profile, 'change:profileID', @profileIDChanged)
		
		@setUpInstructions()
		
		if profileID = profile.get('profileID')
			@profileIDChanged(profile, profileID)
	
	
	setUpInstructions: ->
		instructionsHTML = JST['instructions-encourage-hover']()
		@$('#encourageInstructions').html(instructionsHTML)
		
	
	setUpResults: =>
		pageURL = @currentPageURL
		return if not pageURL
		
		
		if @results?
			@stopListening(@results)
			
			@results = null
		
		
		if @pageURLsToResults[pageURL]
			results = @pageURLsToResults[pageURL]
		else
			results = @profile.requestResultsWithOptions pageURL: pageURL
			@pageURLsToResults[pageURL] = results
		
		# Check if All Times View has changed, if it has then reload all stats.
		
		@results = results
		
		@listenTo(results, 'change:pageURL', @displayTargetInfo)
		
		@listenTo(results, 'change:todaysUniqueVisitors change:todaysTopSource', @displayTodaysNumbers)
		@listenTo(results, 'change:newAndReturningVisitors', @displayVisitorLoyalty)
		@listenTo(results, 'change:totalPageViews change:averageTimeOnPage change:entranceRate', @displayTotalNumbers)
		@listenTo(results, 'change:dailyUniqueVisitors change:dailyUniqueVisitorsWithNewVsReturningCompared', _.throttle(@displayDailyUniqueVisitorsGraph, 50))
		@listenTo(results, 'change:visitorsCount', @displayRecentNumbers)
		@listenTo(results, 'change:topSources', @displayTopSources)
		
		
		for sectionID, sectionInfo of @sectionsInfo
			if sectionInfo.resultsEvents
				@listenTo results, sectionInfo.resultsEvents, =>
					return unless sectionInfo.isEnabled
					
					@needsRender()
		
		
		@setUpResultsForActiveSource()
		@setUpResultsForComparingNewVsReturning()
	
	
	setUpResultsForActiveSource: =>
		@resultsForActiveSource = null
		
		pageURL = @currentPageURL
		return if not pageURL
		
		results = null
		if @activeOptions.topSourceID
			activeSourceID = @activeOptions.topSourceID
			results = @profile.requestResultsWithOptions {pageURL, activeSourceID}
		
		if results?
			@resultsForActiveSource = results
			
			@listenTo results, 'change:dailyUniqueVisitors change:dailyUniqueVisitorsWithNewVsReturningCompared', _.throttle(@displayDailyUniqueVisitorsGraph, 50)
	
	
	setUpResultsForComparingNewVsReturning: =>
		@resultsForComparingNewVsReturning = null
		
		pageURL = @currentPageURL
		return if not pageURL
		
		results = null
		if @activeOptions.compareNewVsReturning
			compareNewVsReturning = @activeOptions.compareNewVsReturning
			results = @profile.requestResultsWithOptions {pageURL, compareNewVsReturning}
		
		if results?
			@resultsForComparingNewVsReturning = results
			
			@listenTo(results, 'change:dailyUniqueVisitors', _.throttle(@displayDailyUniqueVisitorsGraph, 50))

	
	setUpHeight: =>
		height = @height = @baseHeight
		@trigger('change:height', this, height)
	
	
	setEnabledSections: (enabledSections) =>
		enabledSections = _.pick(enabledSections, _.keys(@sectionsInfo))
		
		for sectionID, isEnabled of enabledSections
			#console.log('CHNAGE SECTION is enabled', isEnabled)
			@adjustSection sectionID, {show: isEnabled}
	
	
	infoForJSTSection: ->
		{
			@results
			@isViewingCurrentPage
			@activeOptions
			burntFavIconImageURLForSourceID: root.burntFavIconImageURLForSourceID
			burntDisplayTextForCount: root.garnishCount
			burntDisplayDurationForSeconds: root.garnishDurationWithSeconds
			burntDisplayNumberWithDecimalPlaces: root.garnishNumberWithDecimalPlaces
			burntURLDomainForSourceID: root.burntURLDomainForSourceID
			daysPerMonth: 30
		}
	
	
	htmlForSection: (sectionID) ->
		return JST[sectionID](@infoForJSTSection())
	
	
	displayVisibleSections: =>
		for sectionID, sectionInfo of @sectionsInfo
			#console.log('DISPLAY SECTION:', sectionID)
			#console.log('RENDER SECTION', sectionInfo.isEnabled)
			
			return unless sectionInfo.isEnabled
			
			if sectionInfo.template?
				# Automated use of JST.
				sectionElement = @$(sectionInfo.el)
				sectionElement.html(@htmlForSection(sectionInfo.template))
			else if sectionInfo.display?
				# Call display function.
				@[sectionInfo.display].call(this)
			
			@adjustSection sectionID
		
	
	render: =>
		if (@profile.get 'profileID') and @results?
			@displayTargetInfo()
			
			@displayTodaysNumbers()
			@displayVisitorLoyalty()
			@displayRecentNumbers()
			@displayTotalNumbers()
			@displayDailyUniqueVisitorsGraph()
			@displayTopSources()
			
			@displayVisibleSections()
		
		
		@$("#sectionOptions a[data-section-i-d]").each (index, element) =>
			button = jQuery element
			sectionID = button.data 'sectionID'
			isEnabled = @sectionIsEnabled sectionID
			button.toggleClass 'selected', isEnabled
		
		@needsRenderFlag = false
		
		return
	
	
	needsRender: =>
		if not @needsRenderFlag
			@needsRenderFlag = true
			_.defer @render
		
	
	changeHeightBy: (difference) =>
		@height += difference
		@trigger('change:height', this, @height)
	
	
	sectionIsEnabled: (sectionID) =>
		sectionInfo = @sectionsInfo[sectionID]
		return sectionInfo.isEnabled ? false
	
	
	adjustSection: (sectionID, options) =>
		# console.log('ADJUST SECTION', sectionID, options)
		
		sectionInfo = @sectionsInfo[sectionID]
		unless sectionInfo.adjustsHeight? then return
		
		sectionElement = @$(sectionInfo.el)
		
		previousHeight = sectionElement.data('previousHeight') ? 0
		newHeight = null
		
		if options?.toggle
			currentlyEnabled = @sectionIsEnabled(sectionID)
			options.show = not currentlyEnabled
		
		if options?.show?
			show = options.show
			sectionInfo.isEnabled = show
			sectionElement.toggle show
			#console.log 'SHOWING SECTION:', sectionElement.is ':visible'
			newHeight = if show then sectionElement.outerHeight() else 0
			
			@trigger('sectionIsEnabledChanged', this, sectionID, show)
			
			@needsRender()
		else
			newHeight = sectionElement.outerHeight()
		
		#console.log 'CHANGING HEIGHT FOR SECTION:', newHeight, previousHeight
		
		if newHeight? and newHeight != previousHeight
			@changeHeightBy(newHeight - previousHeight)
			sectionElement.data('previousHeight', newHeight)
		
	
	displayTargetInfo: =>
		html = @htmlForSection('page-target-info')
		@$('#pageTargetInfo').html html
	
	
	displayTodaysNumbers: =>
		pageResultsHTML = @htmlForSection('stats-todays-numbers')
		@$('#todaysNumbers').html pageResultsHTML
	
	
	displayVisitorLoyalty: =>
		pageResultsHTML = @htmlForSection('stats-visitor-loyalty')
		@$('#visitorLoyalty').html pageResultsHTML
	

	displayTotalNumbers: =>
		pageResultsHTML = @htmlForSection('stats-total-numbers')
		@$('#totalNumbers').html pageResultsHTML
	
	
	displayDailyUniqueVisitorsGraph: =>
		#console.log('displayDailyUniqueVisitorsGraph')
		@displayDailyUniqueVisitorsGraphD3()
	
	
	compareDatedDataProperty: (dataList, propertyToCompare) ->
		newData = for d in dataList[0]
			baseD = _.clone(d)
			baseD.comparedValues = []
			baseD
		
		for data in dataList
			for i, d in data
				value = d[propertyToCompare]
				newData[i].comparedValues.push(value)
		
		return newData
	
	
	getCurrentStackInfo: (options = {}) ->
		compareNewVsReturning = options.compareNewVsReturning ? true
		
		if compareNewVsReturning
			stackInfo = [
				{
					getValue: (d) -> d.newVisitorCount ? 0
					elementClass: 'newVisitors'
				}
				{
					getValue: (d) -> d.returningVisitorCount ? 0
					elementClass: 'returningVisitors'
				}
			]
		else
			stackInfo = [
				{
					getValue: (d) -> d.visitorCount ? 0
					elementClass: 'allVisitors'
				}
			]
		
		stackInfo
	
	
	makeDatedDataLayersForStackInfo: (datedData, stackInfo) =>
		layers = for info in stackInfo
			for d in datedData
				#if typeof(info.getValue(d)) === 'undefined'
				#console.log('UDNEFIEND', d, info)
				
				value = info.getValue(d)
				if isNaN(value) then value = 0
				
				{
					date: d.date,
					count: value
				}
		
		layers
	
	
	displayDailyUniqueVisitorsGraphD3: =>
		#results = @resultsForComparingNewVsReturning || @results
		results = @results
		
		$chartHolder = @$('#topCharts')
		
		#dailyUniqueVisitors = results.get('dailyUniqueVisitors')
		dailyUniqueVisitors = results.get('dailyUniqueVisitorsWithNewVsReturningCompared')
		unless dailyUniqueVisitors?.length > 0
			$chartHolder.find('svg').remove()
			return
		
		hasActiveSource = @resultsForActiveSource?
		compareNewVsReturning = not hasActiveSource
		#compareNewVsReturning = false
		
		
		pageURL = results.get('pageURL')
		uniqueResultID = (itemID) ->
			"#{pageURL}: #{itemID}"
		
		# Extract data to certain times
		earlierData = _.initial(dailyUniqueVisitors, 6)
		recentData = _.last(dailyUniqueVisitors, 7)
		weekEarlier1Data = dailyUniqueVisitors.slice(14, 21)
		
		# Get Chart element
		chartHolderElement = $chartHolder.get(0)
		fullWidth = $chartHolder.width()
		fullHeight = 50
		
		# Set up SVG
		svg = d3.select(chartHolderElement).select('svg')
		if svg.empty()
			svg = d3.select(chartHolderElement).append('svg').attr('width', '100%').attr('height', fullHeight + 20)
		
		# Scales
		widthScaleX = d3.scale.linear().range([0, fullWidth])
		fullScaleY = d3.scale.linear().range([fullHeight, 0]).domain([0, d3.max(dailyUniqueVisitors, (d) -> d.visitorCount)]).nice()
		
		# Time formatters
		dayFormatter = d3.time.format '%e'
		monthFormatter = d3.time.format '%b'
		dayMonthFormatter = d3.time.format '%b %e'
		weekIndexFormatter = d3.time.format '%w'
		weekIDs = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday']
		weekInitials = ['S', 'M', 'T', 'W', 'T', 'F', 'S']
		weekInitialFormatter = (date) ->
			weekdayIndex = parseInt(weekIndexFormatter(date), 10)
			return weekInitials[weekdayIndex]
		
		
		earlierToRecentFraction = (3.0 / 5.0)
		
		earlierScaleX = do (s = d3.time.scale()) ->
			s.range [0, widthScaleX(earlierToRecentFraction)]
			s.domain [_.first(earlierData).date, _.last(earlierData).date]
			s
		
		dateForFirstTick = earlierData[2].date
		currentWeekdayIndex = parseInt(weekIndexFormatter(dateForFirstTick), 10)
		weekIntervalID = weekIDs[currentWeekdayIndex]
		weekInterval = d3.time[weekIntervalID]
		earlierTicksScaleX = do (s = d3.time.scale()) ->
			s.range [earlierScaleX(dateForFirstTick), widthScaleX(earlierToRecentFraction)]
			s.domain [dateForFirstTick, _.last(earlierData).date]
			s
		
		recentScaleX = do (s = d3.time.scale()) ->
			s.range [widthScaleX(earlierToRecentFraction), widthScaleX(1.0)]
			s.domain [_.first(recentData).date, _.last(recentData).date]
			s
		
		#comparedWeekScaleX = d3.time.scale().range([widthScaleX(0.5), widthScaleX(1.0)]).domain([_.first(weekEarlier1Data).date, _.last(weekEarlier1Data).date])
		
		
		# SCALES #
		fullScaleX = (inputDate) ->
			if inputDate >= _.first(recentData).date
				recentScaleX(inputDate)
			else
				earlierScaleX(inputDate)
		
		
		# INFO LAYERS #
		stackInfo = @getCurrentStackInfo({compareNewVsReturning})
		
		datedDataLayers = @makeDatedDataLayersForStackInfo(dailyUniqueVisitors, stackInfo)
		
		# STACK #
		stack = do (s = d3.layout.stack()) ->
			s.x (d, i) ->
				fullScaleX(d.date)
			s.y (d, i) ->
				d.count
			s
		stackedDayData = stack(datedDataLayers)
		#console.log 'stackedDayData', stackedDayData
			
		
		# AREAS #
		stackedArea = d3.svg.area()
		stackedArea.x (d) -> fullScaleX(d.date)
		stackedArea.y0 (d) -> fullScaleY(d.y0)
		stackedArea.y1 (d) ->
			fullScaleY(d.y0 + d.y)
		
		
		# LINES #
		chartLine = d3.svg.line()
		chartLine.x (d) -> fullScaleX(d.date)
		chartLine.y (d) -> fullScaleY(d.y)

		
		#earlierScaleX = d3.time.scale().range([0, widthScaleX(0.5)]).domain(d3.extent(earlierData, function(d) { return d.date}))
		
		#earlierScaleX = d3.time.scale().range([0, widthScaleX(0.5)]).domain([earlierData[14].date, _.last(earlierData).date])
		earlierLine = d3.svg.line()
		earlierLine.x (d) -> earlierScaleX(d.date)
		earlierLine.y (d) -> fullScaleY(d.visitorCount)
		
		earlierArea = d3.svg.area()
		earlierArea.x (d) -> earlierScaleX(d.date)
		earlierArea.y0 fullScaleY.range()[0]
		earlierArea.y1 (d) -> fullScaleY(d.visitorCount)
		
		earlierTimeAxis = d3.svg.axis()
		earlierTimeAxis.scale(earlierTicksScaleX)
		earlierTimeAxis.orient('bottom')
		earlierTimeAxis.ticks(4)
			#earlierTimeAxis.tickValues(weekInterval.range(earlierScaleX.domain()[0], weekInterval.offset(earlierScaleX.domain()[1], 1)))
		earlierTimeAxis.tickValues(weekInterval.range(earlierTicksScaleX.domain()[0], weekInterval.offset(earlierTicksScaleX.domain()[1], 1), 1))
		earlierTimeAxis.tickSubdivide(6)
		earlierTimeAxis.tickSize(4, 2, 0)
		earlierTimeAxis.tickPadding(3)
			
		#console.log('TICK VALUES', earlierTimeAxis.ticks())
		#var earlierTimeTicks = earlierTimeAxis.tickValues().splice(1)
		earlierTimeAxis.tickFormat (date, index) ->
			dayMonthFormatter(date)
		
		recentLine = d3.svg.line()
		recentLine.x (d) -> recentScaleX d.date
		recentLine.y (d) -> fullScaleY d.visitorCount
		
		recentArea = d3.svg.area()
		recentArea.x (d) -> recentScaleX d.date
		recentArea.y0 fullScaleY.range()[0]
		recentArea.y1 (d) -> fullScaleY d.visitorCount
		
		recentTimeAxis = d3.svg.axis()
		recentTimeAxis.scale recentScaleX
		recentTimeAxis.orient 'bottom'
		recentTimeAxis.ticks d3.time.days, 1
		recentTimeAxis.tickSize 4
		recentTimeAxis.tickPadding 3
		#recentTimeAxis.tickFormat(recentScaleX.tickFormat(recentTimeAxis.ticks()))
		recentTimeAxis.tickFormat (date, index) ->
			return null if index is 6 or index < 2
			weekInitialFormatter date
		
		
		displayPathsForStackedChart = (gMain, data, stackInfo, pathMaker) ->
			path = gMain.selectAll('path').data data, (d, i) ->
				return uniqueResultID( if stackInfo[i] then stackInfo[i].elementClass else i )
				
			path.attr 'class', (data, i) ->
				#console.log('Update Path element class', i, stackInfo[i] ? stackInfo[i].elementClass : null)
				if stackInfo[i] then stackInfo[i].elementClass else i
				
			# Enter
			path.enter().append('path')
			.attr 'class', (data, i) ->
				stackInfo[i].elementClass
			
			# Update
			path.attr('d', pathMaker)
			
			# Exit
			path.exit()
				.remove()
				
			
		
		
		chartMaker = (base, className, timeAxis, scaleY) ->
			chart = base.selectAll("g.#{className}").data([[]])
			#if chart.empty()
			# Chart
			enteredChart = chart.enter()
				.append('g')
				.attr('class', "chart #{className}")
			# Path
			enteredChart.append('g')
				.attr('class', 'main')
			# Axis
			enteredChart.append('g')
				.attr('class', 'timeAxis timeAxisEarlier')
			
			enteredChart.append('g')
				.attr('class', 'timeAxis timeAxisRecent')
			
			# Update
			
			chart.selectAll('g.timeAxisEarlier')
				.attr('transform', "translate(0, #{scaleY(0) - 2})")
				.call(earlierTimeAxis)
				#.call(timeAxis)
			
			chart.selectAll('g.timeAxisRecent')
				.attr('transform', "translate(0, #{scaleY(0) - 2})")
				.call(recentTimeAxis)
			
			chart
		
		
		if false
			# EARLIER CHART #
			earlierChart = chartMaker(svg, 'earlierChart', earlierTimeAxis, fullScaleY)
			
			earlierStackedData = _.map(stackedDayData, (data, i) ->
				return _.initial(data, 6)
			)
			earlierChartMainGroup = svg.select('g.earlierChart g.main')
			earlierChartMainGroup.classed('hasActiveSource', hasActiveSource)
			if hasActiveSource or true
				displayPathsForStackedChart(earlierChartMainGroup, earlierStackedData, stackInfo, chartLine)
			else
				displayPathsForStackedChart(earlierChartMainGroup, earlierStackedData, stackInfo, stackedArea)
			
			
			# RECENT CHART #
			recentChart = chartMaker(svg, 'recentChart', recentTimeAxis, fullScaleY)
			
			recentStackedData = _.map(stackedDayData, (data, i) ->
				return _.last(data, 7)
			)
			recentChartMainGroup = svg.select('g.recentChart g.main')
			recentChartMainGroup.classed('hasActiveSource', hasActiveSource)
			if hasActiveSource and false
				displayPathsForStackedChart(recentChartMainGroup, recentStackedData, stackInfo, chartLine)
			else
				displayPathsForStackedChart(recentChartMainGroup, recentStackedData, stackInfo, stackedArea)
		else
			entireChart = chartMaker(svg, 'entireChart', earlierTimeAxis, fullScaleY)
			entireChartMainGroup = svg.select('g.entireChart g.main')
			displayPathsForStackedChart(entireChartMainGroup, stackedDayData, stackInfo, stackedArea)
		
		
		# ACTIVE SOURCE #
		
		activeSourcePastMonthData = []
		activeSourcePastWeekData = []
		
		if hasActiveSource
			activeSourceDailyUniqueVisitors = @resultsForActiveSource.get('dailyUniqueVisitors')
			if activeSourceDailyUniqueVisitors
				activeSourcePastMonthData = [ _.initial(activeSourceDailyUniqueVisitors, 6) ]
				activeSourcePastWeekData = [ _.last(activeSourceDailyUniqueVisitors, 7) ]
		
			activeSourceMaker = (chart, data, area) ->
				s = chart.selectAll('g.activeSource').data(data)
				
				enter = s.enter().append('g')
				enter.attr('class', 'activeSource')
				enter.append('path')
				
				p = s.select('path')
				p.attr('d', area)
				
				s.exit().remove()
			
			# Earlier chart's active source
			activeSourceMaker(earlierChart, activeSourcePastMonthData, earlierArea)
			
			# Recent chart's active source
			activeSourceMaker(recentChart, activeSourcePastWeekData, recentArea)
		
		
		chartInfo = {
			widthScaleX
			fullScaleY
			recentChart
		}
		#@displayWeekComparisonChart(dailyUniqueVisitors, chartInfo)
	
	
	displayRecentNumbers: ->
		captionHTML = @htmlForSection('stats-chart-captions')
		@$('#recentNumbers').html(captionHTML)
	
	
	displayWeekComparisonChart: (monthOfData, chartInfo) =>
		widthScaleX = chartInfo.widthScaleX
		fullScaleY = chartInfo.fullScaleY
		recentChart = chartInfo.recentChart
		
		weekRecentData = monthOfData.slice(21, 28)
		weekEarlier1Data = monthOfData.slice(14, 21)
		comparedWeekData = @compareDatedDataProperty([weekRecentData, weekEarlier1Data], 'visitorCount')
		
		scaleX = d3.time.scale().range([widthScaleX(0.0), widthScaleX(1.0)]).domain([_.first(weekRecentData).date, _.last(weekRecentData).date])
		
		comparedWeekArea = d3.svg.area()
			.x (d) -> scaleX d.date
			.y1 (d) -> fullScaleY d.comparedValues[0]
		
		comparedWeekChart = recentChart.select "g.comparedWeek"
		if comparedWeekChart.empty()
			comparedWeekChart = recentChart.append "g"
				.attr "class", "comparedWeek"
		
		comparedWeekChart.datum comparedWeekData
		# Clip below
		comparedWeekChart.append "clipPath"
			.attr "id", "recentChart-comparedClipBelow"
			.append "path"
			.attr "d", comparedWeekArea.y0 fullScaleY.range()[0]
		# Clip above
		comparedWeekChart.append "clipPath"
			.attr "id", "recentChart-comparedClipAbove"
			.append "path"
			.attr "d", comparedWeekArea.y0 0
		# Path above
		comparedWeekChart.append "path"
			.attr "class", "comparedPathAbove"
			.attr "clip-path", "url(#recentChart-comparedClipAbove)"
			.attr "d", comparedWeekArea.y0 (d) -> fullScaleY d.comparedValues[1]
		# Path below
		comparedWeekChart.append "path"
			.attr "class", "comparedPathBelow"
			.attr "clip-path", "url(#recentChart-comparedClipBelow)"
			.attr "d", comparedWeekArea
		
	
	displayTopSources: =>
		pageResultsHTML = @htmlForSection('stats-top-sources')
		@$('#topSources').html pageResultsHTML
	
	
	changeActiveOptions: (changes) =>
		_.extend(@activeOptions, changes)
		
		if not _.isUndefined changes.topSourceID
			@setUpResultsForActiveSource()
		
		if not _.isUndefined changes.compareNewVsReturning
			@setUpResultsForComparingNewVsReturning()
	
	
	profileIsAuthorizedChanged: (profile, isAuthorized) =>
		#console.log('profileIsAuthorizedChanged', isAuthorized)
		#if isAuthorized && @profile.get 'profileID'
			#@setUpResults()
			#@render()
	
	
	profileIDChanged: (profile, profileID) =>
		#console.log('PageResultsView profileIDChanged')
		@setUpResults()
		@render()
	
	
	changePageURL: (pageURL, options) =>
		URLComponents = pageURL.split '//'
		#console.log('URL COMPONENTS', URLComponents)
		if URLComponents.length > 1
			URLPath = URLComponents[1] # Part after the :// ie. domain+path+query+hash
			URLPath = URLPath.split('#')[0] # Now just domain+path+query
			URLPath = '/' + _.rest(URLComponents[1].split '/').join '/' # Reduce to just path+query
		else
			URLPath = pageURL
		
		@currentPageURL = URLPath
		@isViewingCurrentPage = options?.isViewingCurrentPage
		
		@setUpResults()
		@render()
	
	
	clickedToggleSectionButton: (event) =>
		button = jQuery event.target
		sectionID = button.data 'sectionID'
		
		@adjustSection sectionID, toggle: true
	
	
	clickedTopSourcesItem: (event) =>
		return # Disabled
		
		button = jQuery event.target
		sourceID = button.data 'sourceID'
		
		if @activeOptions.topSourceID isnt sourceID
			@changeActiveOptions({topSourceID: sourceID})
		else
			@changeActiveOptions({topSourceID: null})
		
		@needsRender()
	
	
	clickedNewVsReturningItem: (event) =>
		return # Disabled
		
		button = jQuery event.target
		
		if @activeOptions.compareNewVsReturning isnt true
			@changeActiveOptions compareNewVsReturning: true
		else
			@changeActiveOptions compareNewVsReturning: false
		
		@needsRender()
	