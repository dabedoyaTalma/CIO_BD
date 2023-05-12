/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOBusinessRules_DelaysDeparturing]    Script Date: 12/05/2023 14:20:20 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ========================================================================
-- Description: Function for Businees Rules "Delays Departuring"
-- Returns:    
--
-- Change History:
--	2019-10-29  Diomer Bedoya: Stored Procedure created
--	2021-02-15	Sebastián Jaramillo: Inclusión RN Nueva PSO LATAM
--	2021-02-15	Sebastián Jaramillo: Inclusión RN Nueva AXM LATAM
--	2021-11-02	Sebastián Jaramillo: Inclusión RN Nueva EYP LATAM
--	2021-12-16 	Sebastián Jaramillo: Inclusión RN Nueva American Airlines
-- ========================================================================
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOBusinessRules_DelaysDeparturing](
	@DelayDeparturing INT,
	@ServiceHeaderId BIGINT,
	@CompanyId INT,
	@BillingToCompany INT,
	@BaseId INT,
	@ServiceTypeId INT,
	@ServiceDate DATETIME2(0)
)
RETURNS @T_RESULT TABLE (DescriptionType NVARCHAR(300), Percentage NVARCHAR(4), Consideration NVARCHAR(100), DelayDeparturing INT, TimeExcluded INT, DelayDeparturingTotal INT)
AS
BEGIN
	--DECLARE @DelayDeparturing INT = (select [CIOReglaNegocio].[UFN_DelayTimeDeparturing](15312))
	--DECLARE @ServiceHeaderId BIGINT = 15312
	--DECLARE @CompanyId INT = 44
	--DECLARE @BillingToCompany INT = 44
	--DECLARE @BaseId INT = 3
	--DECLARE @ServiceTypeId INT = 1
	--DECLARE @ServiceDate DATETIME2(0) = '2019-09-07'

	IF (@ServiceTypeId IN (5,6)) --ESCALA TECNICA Y REGRESO A PLATAFORMA NO DEBEN MOSTRAR COBRO DE DEMORAS PARA NINGUN CLIENTE
	BEGIN
		RETURN
	END

	DECLARE @Percentage VARCHAR(30)=''
	DECLARE @TimeExcluded INT = (SELECT CIOReglaNegocio.UFN_CIOBusinessRules_ExcludedDelayTimeDeparting(@ServiceHeaderId, @CompanyId, @BillingToCompany, @BaseId, @ServiceTypeId, @ServiceDate))

	DECLARE @DelayDeparturingTotal INT = @DelayDeparturing - @TimeExcluded

	IF (@DelayDeparturingTotal > 0)
	BEGIN

		IF (@CompanyId = 43 AND @BillingToCompany = 43) --AMERICAN AIRLINES A AMERICAN AIRLINES
		BEGIN
			IF (@ServiceDate >= '2021-12-04')
			BEGIN
				IF(@DelayDeparturingTotal BETWEEN 121 AND 181)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '15%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END

				IF(@DelayDeparturingTotal BETWEEN 182 AND 242)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '30%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END

				IF(@DelayDeparturingTotal BETWEEN 243 AND 303)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '45%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END

				IF(@DelayDeparturingTotal > 303)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '50%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END

				RETURN
			END
		END

		-- PARA AVIANCA
		IF((@CompanyId IN (1,193,42,38,41,39,55,11,58) AND @BillingToCompany<>11 AND @BillingToCompany<>90 AND @ServiceTypeId NOT IN (24,25)) OR @CompanyId=91 OR (@CompanyId IN (37) AND @BaseId NOT IN (26/*FLA*/)))
		BEGIN
			IF (@ServiceDate <= '2017-03-15') --HASTA ESTA FECHA SE FACTURARON DEMORAS EN AVA POR EL NUEVO CONTRATO NO SE PUEDEN COBRAR
			BEGIN
				IF (@BillingToCompany = 91 AND @ServiceTypeId IN (24,25) AND @BaseId = 5) --CON AVIATECA EN ADZ NO SE COBRAN DEMORAS EN MTO TTO Y MTO PNTA
				BEGIN
					RETURN
				END

				IF(@DelayDeparturingTotal BETWEEN 121 AND 151)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '15%', '15% transito o pernocta (Por 2,5 horas demorado)', @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END

				IF(@DelayDeparturingTotal BETWEEN 152 AND 182)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '30%', '30% transito o pernocta (Por 3 horas demorado)', @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END

				IF(@DelayDeparturingTotal BETWEEN 183 AND 213)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '45%', '45% transito o pernocta (Por 3,5 horas demorado)', @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END

				IF(@DelayDeparturingTotal>=214)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '60%', '60% transito o pernocta (Por 4 o mas horas demorado)', @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END

				RETURN
			END
			ELSE
			BEGIN
				RETURN --A PARTIR DEL 2017-03-16 NO SE COBRAN DEMORAS
			END
		END

		-- VIVA COLOMBIA
		IF(@CompanyId = 60 AND @BillingToCompany = 90 AND @ServiceDate >= '2017-11-01')
		BEGIN
			IF (@ServiceTypeId IN (24, 25, 27, 28, 29))
			BEGIN
				INSERT	@T_RESULT SELECT	NULL, NULL, NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				RETURN
			END

			IF(@DelayDeparturingTotal BETWEEN 122 AND 182)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA SALIENDO', '20%', '20% transito o pernocta (Por 2 horas demorado)', @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
			END

			IF(@DelayDeparturingTotal BETWEEN 183 AND 243)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA SALIENDO', '30%', '30% transito o pernocta (Por 3 horas demorado)', @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
			END

			IF(@DelayDeparturingTotal BETWEEN 244 AND 304)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA SALIENDO', '40%', '40% transito o pernocta (Por 4 horas demorado)', @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
			END

			IF(@DelayDeparturingTotal>=305)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA SALIENDO', '50%', '50% transito o pernocta (Por 5 o mas horas demorado)', @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
			END

			RETURN
		END

		-- GAMMA
		IF(@BillingToCompany IN (36) AND @BaseId IN (26)) --FLA
		BEGIN
			IF(@DelayDeparturingTotal>120)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA SALIENDO', '35%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
			END

			RETURN
		END

		-- ADA
		IF(@BillingToCompany IN (3))
		BEGIN
			IF(@DelayDeparturingTotal>120)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA SALIENDO', '30%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
			END

			RETURN
		END

		-- PARA COPA
		IF(@CompanyId IN (9))
		BEGIN
			IF NOT (@ServiceTypeId IN (24,25) AND @BaseId = 5/*ADZ*/) --PARA MTO COPA ADZ NO SE COBRAN DEMORAS
			BEGIN
				IF(@DelayDeparturingTotal>120)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '30%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END
			END

			RETURN
		END	


		-- PARA JETSMART

			-- PARA COPA
		IF(@CompanyId= 81 AND @BillingToCompany=81)
		BEGIN
			
				IF(@DelayDeparturingTotal>15)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '30%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END
		

			RETURN
		END	

		-- PARA LAN		
		IF(@CompanyId IN (44))
		BEGIN
			IF (@ServiceTypeId IN (25,24))
			BEGIN
				IF (@BaseId = 55) --SMR
				BEGIN
					IF (@ServiceDate <= '2017-11-30') --HASTA ESTA FECHA SE REALIZÓ COBRO DE CANCELACIONES EN MANTENIMIENTO TTO Y PNTA
					BEGIN
						IF(@DelayDeparturingTotal > 120)
						BEGIN
							INSERT	@T_RESULT 
							SELECT	'DEMORA SALIENDO', '50%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
						END
					END
				END

				IF (@BaseId = 5) --ADZ
				BEGIN
					RETURN --*NOTA: SEGÚN LO DICHO POR CORREO ELECTRONICO COPIADO A CMOLINA Y DAGUDELO EN ADZ NO SE COBRAN DEMORAS SALIENDO EN MTO
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
					IF(@DelayDeparturingTotal BETWEEN 61 AND 120)
					BEGIN
						INSERT	@T_RESULT 
						SELECT	'DEMORA SALIENDO', '20%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
					END

					IF(@DelayDeparturingTotal BETWEEN 121 AND 240)
					BEGIN
						INSERT	@T_RESULT 
						SELECT	'DEMORA SALIENDO', '70%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
					END

					IF(@DelayDeparturingTotal > 240)
					BEGIN
						INSERT	@T_RESULT 
						SELECT	'DEMORA SALIENDO', '100%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
					END

					RETURN
				END

				IF (@ServiceDate BETWEEN '2021-02-01' AND '2021-10-26' AND @BaseId = 47) -- PSO
				BEGIN
					IF(@DelayDeparturingTotal BETWEEN 121 AND 240)
					BEGIN
						INSERT	@T_RESULT 
						SELECT	'DEMORA SALIENDO', '70%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
					END

					IF(@DelayDeparturingTotal > 240)
					BEGIN
						INSERT	@T_RESULT 
						SELECT	'DEMORA SALIENDO', '100%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
					END

					RETURN
				END

				IF (@ServiceDate BETWEEN '2021-06-05' AND '2021-10-26' AND @BaseId = 9) -- AXM
				BEGIN
					IF(@DelayDeparturingTotal BETWEEN 121 AND 240)
					BEGIN
						INSERT	@T_RESULT 
						SELECT	'DEMORA SALIENDO', '70%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
					END

					IF(@DelayDeparturingTotal > 240)
					BEGIN
						INSERT	@T_RESULT 
						SELECT	'DEMORA SALIENDO', '100%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
					END

					RETURN
				END

				---REGLAS GENERICA PARA EL RESTO DE BASES DE LAN

				IF(@DelayDeparturingTotal BETWEEN 91 AND 151)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '10%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END
		
				IF(@DelayDeparturingTotal BETWEEN 152 AND 212)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '20%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END
		
				IF(@DelayDeparturingTotal BETWEEN 213 AND 273)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '30%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END
		
				IF(@DelayDeparturingTotal BETWEEN 274 AND 334)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '40%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END
		
				IF(@DelayDeparturingTotal >=335)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '50%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END
			END

			RETURN
		END

		-- LC PERÚ / AVENTURS
		IF(@CompanyId = 66 AND @BillingToCompany = 60)
		BEGIN
			IF(@DelayDeparturingTotal BETWEEN 91 AND 151)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA SALIENDO', '10%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
			END
		
			IF(@DelayDeparturingTotal BETWEEN 152 AND 212)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA SALIENDO', '20%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
			END
		
			IF(@DelayDeparturingTotal BETWEEN 213 AND 273)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA SALIENDO', '30%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
			END
		
			IF(@DelayDeparturingTotal BETWEEN 274 AND 334)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA SALIENDO', '40%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
			END
		
			IF(@DelayDeparturingTotal >=335)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA SALIENDO', '50%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
			END
			RETURN
		END

		IF (@CompanyId = 228 AND @BillingToCompany = 228) --GRAN COLOMBIA DE AVIACION (GCA) A GRAN COLOMBIA DE AVIACION (GCA)
		BEGIN
			IF (@ServiceDate >= '2020-12-02')
			BEGIN
				IF(@DelayDeparturingTotal BETWEEN 61 AND 121)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '10%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END
		
				IF(@DelayDeparturingTotal BETWEEN 122 AND 182)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '20%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END
		
				IF(@DelayDeparturingTotal BETWEEN 183 AND 243)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '30%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END
		
				IF(@DelayDeparturingTotal BETWEEN 244 AND 304)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '40%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END
		
				IF(@DelayDeparturingTotal >= 305)
				BEGIN
					INSERT	@T_RESULT 
					SELECT	'DEMORA SALIENDO', '50%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
				END
				RETURN
			END

			RETURN
		END

		-- EASY FLY
		IF(@CompanyId = 11 AND @BillingToCompany = 11)
		BEGIN
			IF(@DelayDeparturingTotal BETWEEN 91 AND 151)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA SALIENDO', '10%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
			END
		
			IF(@DelayDeparturingTotal BETWEEN 152 AND 212)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA SALIENDO', '20%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
			END
		
			IF(@DelayDeparturingTotal BETWEEN 213 AND 273)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA SALIENDO', '30%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
			END
		
			IF(@DelayDeparturingTotal BETWEEN 274 AND 334)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA SALIENDO', '40%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
			END
		
			IF(@DelayDeparturingTotal >=335)
			BEGIN
				INSERT	@T_RESULT 
				SELECT	'DEMORA SALIENDO', '50%', NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
			END
			RETURN
		END
	END	
	ELSE
	BEGIN
		INSERT	@T_RESULT
		SELECT	NULL, NULL, NULL, @DelayDeparturing, @TimeExcluded, @DelayDeparturingTotal
	END

	RETURN
END