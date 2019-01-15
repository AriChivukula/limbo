var gulp = require("gulp");
var babel = require("gulp-babel");
var replace = require("gulp-string-replace");
var source = require("vinyl-source-stream");
var ts = require("gulp-typescript");

var project = ts.createProject("tsconfig.json");

gulp.task(
  "build:0",
  () => gulp.src(["source/*.ts"])
    .pipe(project())
    .js
    .pipe(gulp.dest("build/")),
);

gulp.task(
  "build:1",
  () => gulp.src("build/*.js")
    .pipe(babel({
      presets: [["@babel/preset-env", { "modules": false }]],
    }))
    .pipe(gulp.dest("build/")),
);

gulp.task(
  "build:2",
  () => gulp.src("source/*.json")
    .pipe(replace("TRAVIS_BUILD_NUMBER", process.env.TRAVIS_BUILD_NUMBER))
    .pipe(gulp.dest("build/")),
);

gulp.task(
  "build",
  gulp.series(
    "build:0",
    "build:1",
    "build:2",
  ),
);
