-- Migration: Add validation to ensure app_config model values exist in models table
-- This ensures data integrity - default_model, onboarding_model, and quick_reply_model
-- must reference valid model_id values from the models table

-- ========================================
-- 1. Create function to validate model exists
-- ========================================
CREATE OR REPLACE FUNCTION validate_model_exists(model_id_value TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- Check if model exists and is active
  RETURN EXISTS (
    SELECT 1 
    FROM models 
    WHERE model_id = model_id_value 
    AND is_active = true
  );
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- 2. Add check constraint to app_config
-- ========================================
-- This ensures that model-related config values reference valid models
-- We'll use a trigger instead of a check constraint for better error messages

-- ========================================
-- 3. Create trigger function to validate model configs
-- ========================================
CREATE OR REPLACE FUNCTION validate_app_config_models()
RETURNS TRIGGER AS $$
DECLARE
  model_keys TEXT[] := ARRAY['default_model', 'onboarding_model', 'quick_reply_model'];
  model_key TEXT;
BEGIN
  -- Only validate if this is a model-related key
  IF NEW.key = ANY(model_keys) THEN
    -- Check if the model exists in models table
    IF NOT validate_model_exists(NEW.value) THEN
      RAISE EXCEPTION 'Model "%" does not exist in models table or is not active. Please add it to the models table first.', NEW.value;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- 4. Create trigger on app_config
-- ========================================
DROP TRIGGER IF EXISTS t_validate_app_config_models ON app_config;
CREATE TRIGGER t_validate_app_config_models
  BEFORE INSERT OR UPDATE ON app_config
  FOR EACH ROW
  EXECUTE FUNCTION validate_app_config_models();

-- ========================================
-- 5. Validate existing app_config entries
-- ========================================
-- Check if existing config values are valid
DO $$
DECLARE
  invalid_configs TEXT[];
  config_record RECORD;
BEGIN
  invalid_configs := ARRAY[]::TEXT[];
  
  -- Check each model-related config
  FOR config_record IN 
    SELECT key, value 
    FROM app_config 
    WHERE key IN ('default_model', 'onboarding_model', 'quick_reply_model')
  LOOP
    IF NOT validate_model_exists(config_record.value) THEN
      invalid_configs := array_append(invalid_configs, 
        format('%s = %s', config_record.key, config_record.value));
    END IF;
  END LOOP;
  
  -- Report invalid configs
  IF array_length(invalid_configs, 1) > 0 THEN
    RAISE WARNING 'Found invalid model configs: %', array_to_string(invalid_configs, ', ');
    RAISE WARNING 'Please ensure these models exist in the models table and are active.';
    RAISE WARNING 'You can either:';
    RAISE WARNING '  1. Add the missing models to the models table';
    RAISE WARNING '  2. Update app_config to use valid model_id values';
  END IF;
END $$;

-- ========================================
-- 6. Add helpful comment
-- ========================================
COMMENT ON FUNCTION validate_model_exists IS 'Validates that a model_id exists in the models table and is active';
COMMENT ON FUNCTION validate_app_config_models IS 'Trigger function that ensures app_config model values reference valid models';
COMMENT ON TRIGGER t_validate_app_config_models ON app_config IS 'Validates that model-related app_config values reference existing active models';

-- ========================================
-- Notes:
-- - The trigger will prevent inserting/updating app_config with invalid model_id values
-- - Only validates keys: default_model, onboarding_model, quick_reply_model
-- - Models must exist in models table AND be active (is_active = true)
-- - If you get an error, either:
--   1. Add the model to the models table first, then update app_config
--   2. Update app_config to use a model_id that already exists
-- - The validation runs automatically on INSERT and UPDATE operations

