var gulp = require("gulp");
var babel = require("gulp-babel");
var rollup = require("rollup-stream");
var source = require("vinyl-source-stream");
var ts = require("gulp-typescript");
var uglify = require("rollup-plugin-uglify");

var project = ts.createProject("tsconfig.json");

gulp.task(
  "build:1",
  () => gulp.src("source/*.ts")
    .pipe(babel({
      presets: ["@babel/preset-env"],
    }))
    .pipe(gulp.dest("build/")),
);

gulp.task(
  "build:2",
  () => rollup({
    input: "build/index.js",
    format: "cjs",
    plugins: [ uglify.uglify() ],
  })
    .pipe(source("index.js"))
    .pipe(gulp.dest("index.js")),
);

gulp.task(
  "build",
  gulp.series(
    "build:1",
    "build:2",
  ),
);
