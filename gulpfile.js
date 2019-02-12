var gulp = require("gulp");
var babel = require("gulp-babel");
var bro = require("gulp-bro");
var replace = require("gulp-string-replace");
var source = require("vinyl-source-stream");
var ts = require("gulp-typescript");

var project = ts.createProject("tsconfig.json");

gulp.task(
  "build:0",
  () => gulp.src(["source/*.ts"])
    .pipe(project())
    .js
    .pipe(gulp.dest("_1/")),
);

gulp.task(
  "build:1",
  () => gulp.src("_1/*.js")
    .pipe(babel({
      presets: [["@babel/preset-env", { "modules": false }]],
    }))
    .pipe(gulp.dest("_2/")),
);

gulp.task(
  "build:2",
  () => gulp.src("_2/*.js")
    .pipe(bro())
    .pipe(gulp.dest("build/")),
);

gulp.task(
  "build:3",
  () => gulp.src("source/*.json")
    .pipe(replace("TRAVIS_BUILD_NUMBER", process.env.TRAVIS_BUILD_NUMBER))
    .pipe(gulp.dest("build/")),
);

gulp.task(
  "build:4",
  () => gulp.src("icon/*.png")
    .pipe(gulp.dest("build/")),
);

gulp.task(
  "build",
  gulp.series(
    "build:0",
    "build:1",
    "build:2",
    "build:3",
    "build:4",
  ),
);
