/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOBusinessRules_DelaysArriving]    Script Date: 12/05/2023 14:20:11 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ========================================================================
-- Description: Function for Businees Rules "Delays Arriving"
-- Returns:    
--
-- Change History:
--	2019-10-29  Diomer Bedoya: Stored Procedure created
--	2021-02-15	Sebastián Jaramillo: Inclusión RN Nueva PSO LATAM
--	2021-06-30	Sebastián Jaramillo: Inclusión RN Nueva AXM LATAM
--	2021-11-02	Sebastián Jaramillo: Inclusión RN Nueva EYP LATAM
--	2021-12-16 	Sebastián Jaramillo: Inclusión RN Nueva American Airlines
-- ========================================================================
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOBusinessRules_DelaysArriving](
	@DelayArriving INT,
	@ServiceHeaderId BIGINT,
	@CompanyId INT,
	@BillingToCompany INT,
	@BaseId INT,
	@ServiceTypeId INT,
	@ServiceDate DATETIME2(0)
)
RETURNS @T_RESULT TABLE (DescriptionType NVARCHAR(300), Percentage NVARCHAR(4), Consideration NVARCHAR(100), DelayArriving INT, TimeExcluded INT, DelayArrivingTotal INT)
--AS
BEGIN
	--DECLARE @DelayArriving INT = (SELECT [CIOReglaNegocio].[UFN_DelayTimeArriving](15312))
	--DECLARE @ServiceHeaderId BIGINT = 15312
	--DECLARE @CompanyId INT = 44
	--DECLARE @BillingToCompany INT = 44
	--DECLARE @BaseId INT = 1
	--DECLARE @ServiceTypeId INT = 1
	--DECLARE @ServiceDate DATETIME2(0) = '2019-09-07'

	IF (@ServiceTypeId IN (5,6)) --ESCALA TECNICA Y REGRESO A PLATAFORMA NO DEBEN MOSTRAR COBRO DE DEMORAS PARA NINGUN CLIENTE
	BEGIN
		RETURN
	END

	DECLARE @Percentage VARCHAR(30)=''
	DECLARE @TimeExcluded INT = (SELECT [CIOReglaNegocio].[UFN_CIOBusinessRules_ExcludedDelayTimeArriving](@ServiceHeaderId,@CompanyId,@BillingToCompany))

	DECLARE @DelayArrivingTotal INT = @DelayArriving - @TimeExcluded

	IF (@DelayArrivingTotal > 0) --VUELOS DEMORADOS LLEGANDO
	BEGIN

		IF (@CompanyId = 43 AND @BillingToCompany = 43) --AMERICAN AIRLINES A AMERICAN AIRLINES
		BEGIN
			IF (@ServiceDate >= '2021-12-04')
			BEGIN
				IF(@DelayArrivingTotal BETWEEN 121 AND 181)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA LLEGANDO', '15%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END

				IF(@DelayArrivingTotal BETWEEN 182 AND 242)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA LLEGANDO', '30%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END

				IF(@DelayArrivingTotal BETWEEN 243 AND 303)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA LLEGANDO', '45%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END

				IF(@DelayArrivingTotal > 303)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA LLEGANDO', '50%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END

				RETURN
			END
		END

		IF (@BillingToCompany = 91 AND @ServiceTypeId IN (24, 25) AND @BaseId = 5) --CON AVIATECA EN ADZ NO SE COBRAN DEMORAS EN MTO TTO Y MTO PNTA
		BEGIN
			INSERT	@T_RESULT
			SELECT	NULL, NULL, NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal

			RETURN
		END

		-- PARA AVIANCA
		IF((@CompanyId IN (1,193,42,38,41,39,55,11,58) AND @BillingToCompany<>11 AND @BillingToCompany<>90 AND @ServiceTypeId NOT IN (24,25)) OR @CompanyId=91 OR (@CompanyId IN (37) AND @BaseId NOT IN (26/*FLA*/)))
		BEGIN
			IF (@ServiceDate <= '2017-03-15') --HASTA ESTA FECHA SE FACTURARON DEMORAS EN AVA POR EL NUEVO CONTRATO NO SE PUEDEN COBRAR
			BEGIN
				IF(@DelayArrivingTotal BETWEEN 121 AND 151)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA LLEGANDO', '15%', '15% transito o pernocta (Por 2,5 horas demorado)', @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END

				IF(@DelayArrivingTotal BETWEEN 152 AND 182)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA LLEGANDO', '30%', '30% transito o pernocta (Por 3 horas demorado)', @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END

				IF(@DelayArrivingTotal BETWEEN 183 AND 213)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA LLEGANDO', '45%', '45% transito o pernocta (Por 3,5 horas demorado)', @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END

				IF(@DelayArrivingTotal>=214)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA LLEGANDO', '60%', '60% transito o pernocta (Por 4 o mas horas demorado)', @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END

				RETURN
			END
			ELSE
			BEGIN
				INSERT	@T_RESULT
				SELECT	NULL, NULL, NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal

				RETURN --A PARTIR DEL 2017-03-16 NO SE COBRAN DEMORAS
			END
		END

		-- VIVA COLOMBIA
		IF(@CompanyId = 60 AND @BillingToCompany = 90 AND @ServiceDate >= '2017-11-01')
		BEGIN
			IF (@ServiceTypeId IN (24, 25, 27, 28, 29))
			BEGIN
				INSERT	@T_RESULT SELECT	NULL, NULL, NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				RETURN
			END

			--DEMORAS
			IF(@DelayArrivingTotal BETWEEN 61 AND 121)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA LLEGANDO', '10%', '10% transito o pernocta (Por 1 horas adelantado)', @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END

			IF(@DelayArrivingTotal BETWEEN 122 AND 182)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA LLEGANDO', '20%', '20% transito o pernocta (Por 2 horas demorado)', @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END

			IF(@DelayArrivingTotal BETWEEN 183 AND 243)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA LLEGANDO', '30%', '30% transito o pernocta (Por 3 horas demorado)', @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END

			IF(@DelayArrivingTotal BETWEEN 244 AND 304)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA LLEGANDO', '40%', '40% transito o pernocta (Por 4 horas demorado)', @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END

			IF(@DelayArrivingTotal>=305)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA LLEGANDO', '50%', '50% transito o pernocta (Por 5 o mas horas demorado)', @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END

			RETURN
		END

		-- GAMMA
		IF(@BillingToCompany IN (36) AND @BaseId IN (26)) --FLA
		BEGIN
			IF(@DelayArrivingTotal>120)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA LLEGANDO', '35%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END

			RETURN
		END

		-- ADA
		IF(@BillingToCompany IN (3))
		BEGIN
			IF(@DelayArrivingTotal>120)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA LLEGANDO', '30%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END

			RETURN
		END

		-- PARA COPA
		IF(@CompanyId IN (9))
		BEGIN
			IF NOT ((@ServiceTypeId IN (24,25) AND @BaseId = 5/*ADZ*/) OR @ServiceTypeId=14) --PARA MTO COPA ADZ NO SE COBRAN DEMORAS NI TAMPOCO EN LIMPIEZA TERMINAL
			BEGIN
				IF(@DelayArrivingTotal>120)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA LLEGANDO', '30%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END
			END

			RETURN
		END	

		-- PARA LAN		
		IF(@CompanyId IN (7,44))
		BEGIN
			IF (@ServiceTypeId IN (25,24))
			BEGIN
				IF (@ServiceDate <= '2017-11-30') --HASTA ESTA FECHA SE REALIZÓ COBRO DE CANCELACIONES EN MANTENIMIENTO TTO Y PNTA
				BEGIN
					IF	(@BaseId = 5) --ADZ
					BEGIN
						IF(@DelayArrivingTotal > 120)
						BEGIN
							INSERT	@T_RESULT 
							SELECT	'DEMORA LLEGANDO', '30%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
						END
					END
					ELSE IF (@BaseId = 55) --SMR
					BEGIN
						IF(@DelayArrivingTotal > 120)
						BEGIN
							INSERT	@T_RESULT 
							SELECT	'DEMORA LLEGANDO', '50%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
						END
					END
				END
			END
			ELSE
			BEGIN
				IF (@ServiceTypeId = 14) --Limpieza Terminal
				BEGIN
					RETURN --*NOTA: SEGÚN LO DICHO POR CORREO ELECTRONICO COPIADO A CMOLINA Y DAGUDELO NO SE COBRAN DEMORAS PARA LIMPIEZA EN PERNOCTA O LIMPIEZA TERMINAL
				END		

				IF (@ServiceDate >= '2021-10-27' AND @BaseId IN (47, 9, 25)) -- PSO, AXM, EYP
				BEGIN
					IF(@DelayArrivingTotal BETWEEN 61 AND 120)
					BEGIN
						INSERT	@T_RESULT 
						SELECT	'DEMORA LLEGANDO', '20%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
					END

					IF(@DelayArrivingTotal BETWEEN 121 AND 240)
					BEGIN
						INSERT	@T_RESULT 
						SELECT	'DEMORA LLEGANDO', '70%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
					END

					IF(@DelayArrivingTotal > 240)
					BEGIN
						INSERT	@T_RESULT 
						SELECT	'DEMORA LLEGANDO', '100%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
					END

					RETURN
				END

				IF (@ServiceDate BETWEEN '2021-02-01' AND '2021-10-26' AND @BaseId = 47) -- PSO
				BEGIN
					IF(@DelayArrivingTotal BETWEEN 121 AND 240)
					BEGIN
						INSERT	@T_RESULT 
						SELECT	'DEMORA LLEGANDO', '70%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
					END

					IF(@DelayArrivingTotal > 240)
					BEGIN
						INSERT	@T_RESULT 
						SELECT	'DEMORA LLEGANDO', '100%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
					END

					RETURN
				END

				IF (@ServiceDate BETWEEN '2021-06-05' AND '2021-10-26' AND @BaseId = 9) -- AXM
				BEGIN
					IF(@DelayArrivingTotal BETWEEN 121 AND 240)
					BEGIN
						INSERT	@T_RESULT 
						SELECT	'DEMORA LLEGANDO', '70%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
					END

					IF(@DelayArrivingTotal > 240)
					BEGIN
						INSERT	@T_RESULT 
						SELECT	'DEMORA LLEGANDO', '100%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
					END

					RETURN
				END

				IF(@DelayArrivingTotal BETWEEN 91 AND 151)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA LLEGANDO', '10%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END
		
				IF(@DelayArrivingTotal BETWEEN 152 AND 212)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA LLEGANDO', '20%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END
		
				IF(@DelayArrivingTotal BETWEEN 213 AND 273)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA LLEGANDO', '30%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END
		
				IF(@DelayArrivingTotal BETWEEN 274 AND 334)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA LLEGANDO', '40%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END
		
				IF(@DelayArrivingTotal >=335)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA LLEGANDO', '50%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END
			END

			RETURN
		END

		-- LC PERÚ / AVENTURS
		IF(@CompanyId = 66 AND @BillingToCompany = 89)
		BEGIN
			IF(@DelayArrivingTotal BETWEEN 91 AND 151)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA LLEGANDO', '10%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END
		
			IF(@DelayArrivingTotal BETWEEN 152 AND 212)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA LLEGANDO', '20%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END
		
			IF(@DelayArrivingTotal BETWEEN 213 AND 273)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA LLEGANDO', '30%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END
		
			IF(@DelayArrivingTotal BETWEEN 274 AND 334)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA LLEGANDO', '40%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END
		
			IF(@DelayArrivingTotal >=335)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA LLEGANDO', '50%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END
			RETURN
		END

		IF (@CompanyId = 228 AND @BillingToCompany = 228) --GRAN COLOMBIA DE AVIACION (GCA) A GRAN COLOMBIA DE AVIACION (GCA)
		BEGIN
			IF (@ServiceDate >= '2020-12-02')
			BEGIN
				IF(@DelayArrivingTotal BETWEEN 61 AND 121)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '10%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END
		
				IF(@DelayArrivingTotal BETWEEN 122 AND 182)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '20%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END
		
				IF(@DelayArrivingTotal BETWEEN 183 AND 243)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '30%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END
		
				IF(@DelayArrivingTotal BETWEEN 244 AND 304)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '40%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END
		
				IF(@DelayArrivingTotal >= 305)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '50%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END
				RETURN
			END

			RETURN
		END

		-- EASY FLY
		IF(@CompanyId = 11 AND @BillingToCompany = 11)
		BEGIN
			IF(@DelayArrivingTotal BETWEEN 91 AND 151)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA LLEGANDO', '10%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END
		
			IF(@DelayArrivingTotal BETWEEN 152 AND 212)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA LLEGANDO', '20%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END
		
			IF(@DelayArrivingTotal BETWEEN 213 AND 273)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA LLEGANDO', '30%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END
		
			IF(@DelayArrivingTotal BETWEEN 274 AND 334)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA LLEGANDO', '40%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END
		
			IF(@DelayArrivingTotal >=335)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA LLEGANDO', '50%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END
			RETURN
		END

		--VALOR POR DEFECTO
		INSERT	@T_RESULT
		SELECT	NULL, NULL, NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
	END
	ELSE IF (@DelayArrivingTotal < 0) --VUELOS ADELANTADOS LLEGANDO (OJO!! ES LO INVERSO A DEMORA LLEGANDO DEBEN IR NEGATIVOS)
	BEGIN

		--GRAN COLOMBIA DE AVIACION (GCA) A GRAN COLOMBIA DE AVIACION (GCA)
		IF (@CompanyId = 228 AND @BillingToCompany = 228)
		BEGIN
			IF (@ServiceDate >= '2020-12-02')
			BEGIN
				IF(@DelayArrivingTotal BETWEEN -121 AND -61)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'ADELANTO', '10%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END

				IF(@DelayArrivingTotal BETWEEN -182 AND -122)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'ADELANTO', '20%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END

				IF(@DelayArrivingTotal BETWEEN -243 AND -183)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'ADELANTO', '30%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END
				
				IF(@DelayArrivingTotal BETWEEN -304 AND -244)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'ADELANTO', '40%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END

				IF(@DelayArrivingTotal <= -305)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'ADELANTO', '50%', NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				END

				RETURN
			END

			RETURN
		END

		-- VIVA COLOMBIA
		IF(@CompanyId = 60 AND @BillingToCompany = 90 AND @ServiceDate >= '2017-11-01')
		BEGIN
			--ADELANTOS
			IF (@ServiceTypeId IN (24, 25, 27, 28, 29))
			BEGIN
				INSERT	@T_RESULT SELECT	NULL, NULL, NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
				RETURN
			END

			IF(@DelayArrivingTotal BETWEEN -121 AND -61)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'ADELANTO', '10%', '10% transito o pernocta (Por 1 horas adelantado)', @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END

			IF(@DelayArrivingTotal BETWEEN -182 AND -122)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'ADELANTO', '20%', '20% transito o pernocta (Por 2 horas adelantado)', @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END

			IF(@DelayArrivingTotal BETWEEN -243 AND -183)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'ADELANTO', '30%', '30% transito o pernocta (Por 3 horas adelantado)', @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END

			IF(@DelayArrivingTotal BETWEEN -304 AND -244)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'ADELANTO', '40%', '40% transito o pernocta (Por 4 horas adelantado)', @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END

			IF(@DelayArrivingTotal<=-305)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'ADELANTO', '50%', '50% transito o pernocta (Por 5 o mas horas adelantado)', @DelayArriving, @TimeExcluded, @DelayArrivingTotal
			END

			RETURN
		END

		--VALOR POR DEFECTO
		INSERT	@T_RESULT
		SELECT	NULL, NULL, NULL, @DelayArriving, @TimeExcluded, @DelayArrivingTotal
	END

	RETURN
END