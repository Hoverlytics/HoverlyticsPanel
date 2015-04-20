var gulp = require('gulp');
var notify = require('gulp-notify');

gulp.on('err', function(e) {
	console.log(e.err.stack);
});

///////////////////////////////////////////////////////////////////

var version = 3;

//var guilty = require('./gulp-guilty')({
var guilty = require('guilty-gulp')({
	taskNameGroup: 'main',
	baseSrcFolder: './src/v' + version + '/'
});

if (version === 2 || version === 3) {
	guilty.requireTask('images');
	guilty.requireTask('compass', {
		srcFilePath: 'main.scss',
		destCSSPath: './'
	});
	guilty.requireTask('coffee-browserify', {
		srcFilePath: 'app.coffee',
		destFilePath: 'main.js',
		watchPathGlob: '**/*.coffee',
		browserifySetUpCallback: function(browserify) {
			var configFilePath = guilty.isProduction ? '../-config/main-config-gel.js' : '../-config/main-config-dev.js';
			browserify.require(configFilePath, {expose: 'hoverlytics-profile-config'});
		}
	});
	//guilty.requireTask('js-browserify', {srcFilePath: 'main.js'});
	guilty.requireTask('jst');
	guilty.requireTask('copy', {
		taskName: 'vendor-js',
		srcPathGlob: 'vendor-js/porthole.min.js',
		destPath: './'
	});
	guilty.requireTask('html');

	gulp.task(
		guilty.taskNameGroup,
		guilty.taskName([
			'images',
			'compass',
			'coffee-browserify',
			'jst',
			'vendor-js',
			'html'
		])
	);
}
else if (version === 1) {
	guilty.requireTask('images');
	guilty.requireTask('compass', {srcFilePath: 'main.scss', destCSSPath: './'});
	//require('./gulp-guilty/images')(gulp, guilty);
	//require('./gulp-guilty/compass')(gulp, guilty, {srcFilePath: 'main.scss', destCSSPath: './'});
	//require('./gulp-guilty/coffee')(gulp, guilty);
	//require('./gulp-guilty/js')(gulp, guilty);
	require('./gulp-guilty/js-browserify')(gulp, guilty, {srcFilePath: 'main.js', destFilePath: 'main.js'});
	require('./gulp-guilty/jst')(gulp, guilty);
	require('./gulp-guilty/copy')(gulp, guilty, {taskName: 'vendor-js', srcPathGlob: 'vendor-js/porthole.min.js'});
	require('./gulp-guilty/html')(gulp, guilty);

	gulp.task(
		guilty.taskNameGroup,
		guilty.taskName([
			'images',
			'compass',
			//'coffee',
			'js-browserify',
			'jst',
			'vendor-js',
			'html'
			//'js'
		])
	);
}

gulp.task(
	'default',
	[
		guilty.taskNameGroup
	]
);


gulp.task(
	'watch',
	[
		guilty.taskNameGroup,
		guilty.taskName('watch')
	]
);
