#  Copyright (C) 2012 Yusuke Suzuki <utatane.tea@gmail.com>
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are met:
#
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#  ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
#  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
#  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

coffee = require 'coffee-script'
istanbul = require 'istanbul'
crypto = require 'crypto'
escodegen = require 'escodegen'
estraverse = require 'estraverse'
esprima = require 'esprima'

generateTrackerVar = (filename, omitSuffix) ->
    if omitSuffix
        return '__cov_'
    hash = crypto.createHash 'md5'
    hash.update filename
    suffix = hash.digest 'base64'
    suffix = suffix.replace(/\=/g, '').replace(/\+/g, '_').replace(/\//g, '$')
    "__cov_#{suffix}"

class Instrumenter extends istanbul.Instrumenter
    constructor: (opt) ->
        istanbul.Instrumenter.call this, opt

    instrumentSync: (code, filename) ->
        filename = filename or "#{Date.now()}.js"
        @coverState =
            path: filename
            s: {}
            b: {}
            f: {}
            fnMap: {}
            statementMap: {}
            branchMap: {}

        @currentState =
            trackerVar: generateTrackerVar filename, @omitTrackerSuffix
            func: 0
            branch: 0
            variable: 0
            statement: 0

        throw new Error 'Code must be string' unless typeof code is 'string'

        code = coffee.compile code, sourceMap: true
        program = esprima.parse(code.js, loc: true)
        @attachLocation program, code.sourceMap

        @walker.startWalk program
        codegenOptions = @opts.codeGenerationOptions or format: compact: not this.opts.noCompact
        "#{@getPreamble code}\n#{escodegen.generate program, codegenOptions}\n"

    attachLocation: (program, sourceMap)->
        estraverse.traverse program,
            leave: (node, parent) ->
                mappedLocation = (location) ->
                  locArray = sourceMap.getSourcePosition([
                    location.line - program.loc.start.line,
                    location.column - program.loc.start.column])
                  line = 0
                  column = 0
                  if locArray
                    line = locArray[0] + program.loc.start.line
                    column = locArray[1] + program.loc.start.column
                  return { line: line, column: column }

                if node.loc?.start
                  node.loc.start = mappedLocation(node.loc.start)
                if node.loc?.end
                  node.loc.end = mappedLocation(node.loc.end)

                return

module.exports = Instrumenter

# vim: set sw=4 ts=4 et tw=80 :
