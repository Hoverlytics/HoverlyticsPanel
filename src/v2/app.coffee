"Copyright 2013–2015 Patrick Smith"


model = require('./model')
Profile = model.Profile

views = require('./views')
ProfileView = views.ProfileView
PageResultsView = views.PageResultsView

$ = jQuery
$d = $(document)


class App
	masterPageURL: null
	pageURLToLoad: null
	
	constructor: ->
		_.extend this, Backbone.Events
		
		profile = @profile = new Profile
		@listenTo(profile, 'change:profileID', @profileIDChanged)
		@listenTo(profile, 'change:isAuthorized', @isAuthorizedChanged)
		
		@setupSourceCommunication()
		@setupViews()
		
		isAuthorized = profile.get('isAuthorized')
		if isAuthorized?
			profile.trigger('change:isAuthorized', isAuthorized)
	
	
	sendInitialTracking: ->
		ga('send', 'event', 'Panel', 'Loaded', @masterPageURL)
	
	
	setupSourceCommunication: ->
		if location.hash?.length > 1
			info = $.parseJSON(decodeURIComponent(location.hash.substring(1)))
			
			@masterPageURL = info.masterPageURL
			@sendInitialTracking()
			
			#console.log('SOURCE PROXY URL', sourceProxyURL)
			@sourceProxy = sourceProxy = new Porthole.WindowProxy(info.sourceProxyURL)
			sourceProxy.addEventListener(@receivedMessageFromSource)
			
			
			if info.googleAnalyticsProfileID?
				#console.log('googleAnalyticsProfileID', info.googleAnalyticsProfileID)
				@profile.set('profileID', info.googleAnalyticsProfileID)
			
			return
	
	
	setupViews: ->
		profile = @profile
		profileView = @profileView = new ProfileView(model: profile)
		@listenTo(profileView, 'newProfileIDSelected', @newProfileIDSelected)
		
		pageResultsView = this.pageResultsView = new PageResultsView(profile: profile)
		@listenTo(pageResultsView, 'change:height', @pageResultsViewHeightChanged)
		pageResultsView.setUpHeight()
		
		@sendMessageToSource(viewsReady: true)
		
		@listenTo(pageResultsView, 'sectionIsEnabledChanged', @sectionIsEnabledChanged)
		
		return
	
	
	sendMessageToSource: (message) =>
		message.hoverlytics = true
		
		@sourceProxy.post message
	
	
	receivedMessageFromSource: (message) =>
		#console.log('RECEIVED MESSAGE FROM SOURCE', message)
		return if not (message?.data?)
		
		if message.data.changePageURL
			@changeChosenPageURL(message.data.changePageURL)
		else if message.data.enabledSections
			enabledSections = message.data.enabledSections
			#console.log 'received enabledSections', enabledSections
			@pageResultsView.setEnabledSections(enabledSections)
		else if message.data.chooseProfile
			@chooseProfile()
		else if message.data.signOut
			@signOut()
		
		return
	
	
	changeChosenPageURL: (pageURL) =>
		if @profile.get('isAuthorized')
			isViewingCurrentPage = (pageURL is @masterPageURL)
			@pageResultsView.changePageURL(pageURL, isViewingCurrentPage: isViewingCurrentPage)
			
			ga('send', 'event', 'Panel', 'Change Page URL')
			
			$('body').addClass('hasChosenPage')
		else
			#console.log('SAVE PAGE URL FOR LATER', pageURL)
			@pageURLToLoad = pageURL
		
		return
	
	
	setHasAnalyticsProfile: (hasProfile) ->
		$('body').toggleClass('hasAnalyticsProfile', hasProfile)
	
	
	setNeedsAnalyticsProfile: (needsProfile) ->
		$('body').toggleClass('needsAnalyticsProfile', needsProfile)
		
		if needsProfile
			@needsUserAttention()
	
	
	chooseProfile: ->
		@profile.requestListOfAccounts()
		@setHasAnalyticsProfile(false)
		@setNeedsAnalyticsProfile(true)
	
	
	profileIDChanged: (profile, profileID) =>
		@setHasAnalyticsProfile(profileID?)
		@setNeedsAnalyticsProfile(not profileID?)
		
		return
	
	newProfileIDSelected: (profile, profileID) =>
		@sendMessageToSource(newProfileIDSelected: profileID)
		return
	
	
	pageResultsViewHeightChanged: (pageResultsView, newHeight) =>
		@sendMessageToSource(changeHeight: newHeight)
		return
	
	
	sectionIsEnabledChanged: (pageResultsView, sectionID, isEnabled) =>
		@sendMessageToSource(sectionIsEnabledChanged: {sectionID: sectionID, isEnabled: isEnabled})
		return
	
	
	signOut: ->
		@profile.signOutOfGoogle()
	
	
	needsUserAttention: =>
		@sendMessageToSource(needsUser: true)
		return
	
	
	isAuthorizedChanged: (profile, isAuthorized = false) =>
		$('body').toggleClass('authorized', isAuthorized).toggleClass('needsAuthorization', not isAuthorized)
		
		if not isAuthorized
			#@setHasAnalyticsProfile(false)
			#@setNeedsAnalyticsProfile(true)
			#@needsUserAttention()
		else
			ga('send', 'event', 'Panel', 'Authorized', @masterPageURL)
			
			if not @profile.get('profileID')
				@setHasAnalyticsProfile(false)
				@setNeedsAnalyticsProfile(true)
				@profile.requestListOfAccounts()
			
			if @pageURLToLoad
				@changeChosenPageURL(@pageURLToLoad)
		
		return


window.googleClientAPIHasLoaded = false
window.googleClientAPILoaded = ->
	window.googleClientAPIHasLoaded = true
	$d.trigger('googleClientAPILoaded')
	$d.off('googleClientAPILoaded')


window.addGoogleClientAPIReadyCallback = (callback) ->
	if googleClientAPIHasLoaded
		callback()
	else
		$d.on('googleClientAPILoaded', ->
			callback()
			return
		)
	
	return



$d.ready ->
	window.App = new App()
	return


module.exports = App