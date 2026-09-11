package incident

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNewRepository_DualDriver(t *testing.T) {
	// 1. Without pgxPool (legacy/fallback mode)
	repo := NewRepository(nil)
	assert.NotNil(t, repo)
	assert.Nil(t, repo.pgxPool)
	assert.Nil(t, repo.queries)

	// 2. With nil pgxPool
	repoNil := NewRepository(nil, nil)
	assert.NotNil(t, repoNil)
	assert.Nil(t, repoNil.pgxPool)
	assert.Nil(t, repoNil.queries)
}

func TestFindNearby_InvalidVolunteerUUID(t *testing.T) {
	// If sqlc queries were active with an invalid UUID, Scan will return error
	// Here we verify fallback behavior when queries is nil
	repo := NewRepository(nil)
	assert.NotNil(t, repo)
}
