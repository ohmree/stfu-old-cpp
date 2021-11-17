---@diagnostic disable: undefined-global, undefined-field
add_rules("mode.debug", "mode.release")

set_languages("cxx20")
set_defaultmode("debug")

rule("restbuilder")
    set_extensions(".xml")

    on_load(function (target)
        local qrestbuilder = import("lib.detect.find_program")("qrestbuilder")
        local moc = import("lib.detect.find_tool")("moc").program
        assert(qrestbuilder and os.isexec(qrestbuilder), "qrestbuilder not found!")

        local headerfile_dir = path.join(target:autogendir(), "rules", "restbuilder")
        if not os.isdir(headerfile_dir) then
            os.mkdir(headerfile_dir)
        end
        target:add("includedirs", path.absolute(headerfile_dir, os.projectdir()))

        target:data_set("qrestbuilder", qrestbuilder)
        target:data_set("moc", moc)
    end)

    before_buildcmd_file(function (target, batchcmds, sourcefile_xml, opt)
        local qrestbuilder = target:data("qrestbuilder")
        local moc = target:data("moc")
        local headerfile_dir = path.join(target:autogendir(), "rules", "restbuilder")
        local sourcefile_basename = path.join(headerfile_dir, path.basename(sourcefile_xml))
        local implfile = sourcefile_basename .. ".cpp"
        local headerfile = sourcefile_basename .. ".h"
        local mocfile = path.join(headerfile_dir, "moc_" .. path.basename(sourcefile_xml) .. ".cpp")

        batchcmds:show_progress(opt.progress, "${color.build.object}compiling.qrestbuilder.xml %s", sourcefile_xml)
        batchcmds:mkdir(headerfile_dir)
        batchcmds:vrunv(qrestbuilder, {"--in", sourcefile_xml, "--header", headerfile, "--impl", implfile})

        import("core.tool.compiler")
        local flags = {}
        table.join2(flags, compiler.map_flags("cxx", "define", target:get("defines")))
        table.join2(flags, compiler.map_flags("cxx", "includedir", target:get("includedirs")))
        table.join2(flags, compiler.map_flags("cxx", "includedir", target:get("sysincludedirs"))) -- for now, moc process doesn't support MSVC external includes flags and will fail
        table.join2(flags, compiler.map_flags("cxx", "frameworkdir", target:get("frameworkdirs")))
        batchcmds:vrunv(moc, table.join(flags, headerfile, "-o", mocfile))

        local objectfile = target:objectfile(implfile)
        table.insert(target:objectfiles(), objectfile)
        local moc_objectfile = target:objectfile(mocfile)
        table.insert(target:objectfiles(), moc_objectfile)

        batchcmds:compile(implfile, objectfile)
        batchcmds:compile(mocfile, moc_objectfile)

        batchcmds:add_depfiles(sourcefile_xml)
        batchcmds:set_depmtime(os.mtime(objectfile))
        batchcmds:set_depcache(target:dependfile(objectfile))
    end)
rule_end()

package("qcoro")
    add_deps("cmake")
    set_sourcedir(path.join(os.scriptdir(), "vendor", "qcoro"))
    on_install(function (package)
        local configs = {}
        table.insert(configs, "-DCMAKE_BUILD_TYPE=" .. (package:debug() and "Debug" or "Release"))
        table.insert(configs, "-DBUILD_SHARED_LIBS=" .. (package:config("shared") and "ON" or "OFF"))
        table.insert(configs, "-DUSE_QT_VERSION=5")
        table.insert(configs, "-DQCORO_WITH_QTDBUS=OFF")
        import("package.tools.cmake").install(package, configs)
    end)
    on_test(function (package)
        local qt = assert(import("detect.sdks.find_qt")(), "qt not found!")
        local qtcore_includedir = path.join(qt.includedir, "QtCore")
        assert(package:has_cxxtypes("QCoro::Task<QString>", {includes = "qcoro/task.h",
            configs = {includedirs = {qt.includedir, qtcore_includedir},
                       links = "Qt5Core",
                       languages = "cxx20",
                       cxxflags = {"-fPIC", "-fcoroutines", "-fconcepts"}}}))
    end)
package_end()

add_requires("cmake::Qt5RestClientAuth", "qcoro")

target("stfu")
    set_kind("shared")
    add_rules("qt.shared", "restbuilder")
    add_packages("cmake::Qt5RestClientAuth", "qcoro")
    add_files("src/*.cpp")
    add_files("src/api/*.xml")
    add_defines("STFU_LIBRARY")
    add_frameworks("QtCore", "QtGui", "QtWidgets", "QtNetworkAuth", "QtWebSockets")
target_end()
