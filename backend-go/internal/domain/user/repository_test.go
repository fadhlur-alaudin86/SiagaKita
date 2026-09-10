package user

import (
	"testing"
	"time"
)

func TestBuildProfileUpdateMap_AllFields(t *testing.T) {
	fullName := "Jane Doe"
	nik := "3201234567890001"
	phone := "+6281234567890"
	bloodType := "O+"
	pob := "Jakarta"
	allergies := "Peanuts"
	medCond := "None"
	height := 168
	weight := 60
	domicile := "Jakarta Selatan"
	bio := "Emergency volunteer"
	dobStr := "25-12-1995"

	req := &UpdateProfileRequest{
		FullName:          &fullName,
		NIK:               &nik,
		PhoneNumber:       &phone,
		BloodType:         &bloodType,
		PlaceOfBirth:      &pob,
		Allergies:         &allergies,
		MedicalConditions: &medCond,
		HeightCm:          &height,
		WeightKg:          &weight,
		Domicile:          &domicile,
		Bio:               &bio,
		DateOfBirth:       &dobStr,
	}

	result, err := buildProfileUpdateMap(req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if result["full_name"] != fullName {
		t.Errorf("expected full_name %q, got %v", fullName, result["full_name"])
	}
	if result["nik"] != nik {
		t.Errorf("expected nik %q, got %v", nik, result["nik"])
	}
	if result["phone_number"] != phone {
		t.Errorf("expected phone_number %q, got %v", phone, result["phone_number"])
	}
	if result["is_phone_verified"] != false {
		t.Errorf("expected is_phone_verified false, got %v", result["is_phone_verified"])
	}
	if result["blood_type"] != bloodType {
		t.Errorf("expected blood_type %q, got %v", bloodType, result["blood_type"])
	}
	if result["place_of_birth"] != pob {
		t.Errorf("expected place_of_birth %q, got %v", pob, result["place_of_birth"])
	}
	if result["allergies"] != allergies {
		t.Errorf("expected allergies %q, got %v", allergies, result["allergies"])
	}
	if result["medical_conditions"] != medCond {
		t.Errorf("expected medical_conditions %q, got %v", medCond, result["medical_conditions"])
	}
	if result["height_cm"] != height {
		t.Errorf("expected height_cm %d, got %v", height, result["height_cm"])
	}
	if result["weight_kg"] != weight {
		t.Errorf("expected weight_kg %d, got %v", weight, result["weight_kg"])
	}
	if result["domicile"] != domicile {
		t.Errorf("expected domicile %q, got %v", domicile, result["domicile"])
	}
	if result["bio"] != bio {
		t.Errorf("expected bio %q, got %v", bio, result["bio"])
	}

	expectedDOB, _ := time.Parse("02-01-2006", dobStr)
	actualDOB, ok := result["date_of_birth"].(time.Time)
	if !ok || !actualDOB.Equal(expectedDOB) {
		t.Errorf("expected date_of_birth %v, got %v", expectedDOB, result["date_of_birth"])
	}

	if _, ok := result[fieldUpdatedAt]; !ok {
		t.Errorf("expected %q in result map", fieldUpdatedAt)
	}
}

func TestBuildProfileUpdateMap_NilFields(t *testing.T) {
	fullName := "John Only"
	req := &UpdateProfileRequest{
		FullName: &fullName,
	}

	result, err := buildProfileUpdateMap(req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if result["full_name"] != fullName {
		t.Errorf("expected full_name %q, got %v", fullName, result["full_name"])
	}
	if _, exists := result["nik"]; exists {
		t.Errorf("nik should not be present in map when nil")
	}
	if _, exists := result["phone_number"]; exists {
		t.Errorf("phone_number should not be present in map when nil")
	}
	if _, exists := result["is_phone_verified"]; exists {
		t.Errorf("is_phone_verified should not be present when phone_number is nil")
	}
	if _, exists := result["date_of_birth"]; exists {
		t.Errorf("date_of_birth should not be present in map when nil")
	}
}

func TestBuildProfileUpdateMap_InvalidDateFormat(t *testing.T) {
	invalidDOB := "1995-12-25" // YYYY-MM-DD instead of DD-MM-YYYY
	req := &UpdateProfileRequest{
		DateOfBirth: &invalidDOB,
	}

	_, err := buildProfileUpdateMap(req)
	if err == nil {
		t.Fatalf("expected error for invalid date format, got nil")
	}
}
