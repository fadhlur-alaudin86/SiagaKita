package migrations

import "embed"

// FS embeds all .up.sql and .down.sql migration scripts.
//
//go:embed *.sql
var FS embed.FS
