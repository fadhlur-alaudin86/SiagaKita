package user

import (
	"testing"
)

func TestNormalizeRelation(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"ayah", RelationParent},
		{"IBU", RelationParent},
		{" Orang Tua ", RelationParent},
		{"bapak", RelationParent},
		{"mama", RelationParent},
		{"papa", RelationParent},
		{"father", RelationParent},
		{"mother", RelationParent},
		{"parent", RelationParent},
		{"suami", RelationSpouse},
		{"istri", RelationSpouse},
		{"pasangan", RelationSpouse},
		{"spouse", RelationSpouse},
		{"anak", RelationChild},
		{"child", RelationChild},
		{"kakak", RelationSibling},
		{"adik", RelationSibling},
		{"saudara", RelationSibling},
		{"sibling", RelationSibling},
		{"teman", RelationFriend},
		{"sahabat", RelationFriend},
		{"friend", RelationFriend},
		{"other", RelationOther},
		{"lainnya", RelationOther},
		{"tetangga jauh", RelationOther},
		{"", ""},
		{"   ", ""},
	}

	for _, tc := range tests {
		t.Run(tc.input, func(t *testing.T) {
			actual := NormalizeRelation(tc.input)
			if actual != tc.expected {
				t.Errorf("NormalizeRelation(%q) = %q, expected %q", tc.input, actual, tc.expected)
			}
		})
	}
}

func TestIsValidRelation(t *testing.T) {
	valid := []string{
		RelationParent,
		RelationSpouse,
		RelationChild,
		RelationSibling,
		RelationFriend,
		RelationOther,
	}

	for _, r := range valid {
		if !IsValidRelation(r) {
			t.Errorf("expected %q to be valid relation", r)
		}
	}

	invalid := []string{"", "ayah", "mother", "random_string"}
	for _, r := range invalid {
		if IsValidRelation(r) {
			t.Errorf("expected %q to be invalid relation code", r)
		}
	}
}
