/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_TotalCancellation]    Script Date: 12/05/2023 10:36:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =====================================================================================================================================================================
-- Description: Function for Business Rules "TotalCancellation / Arriving"
-- Change History:
--	2019-11-XX XXXXXXXXX: Funtion created
--	2021-11-01 Sebastián Jaramillo: Se incluye RN LATAM Contrato Nuevo EYP
--	2021-12-16 Sebastián Jaramillo: Se incluye RN Contrato Nuevo SARPA
--	2022-04-04	Sebastián Jaramillo: Nueva RN Ultra Air
--	2022-09-28	Sebastián Jaramillo: Se adicionan RN Arajet
--	2023-02-13	Sebastián Jaramillo: Se configura nuevo contrato de Avianca 2023 "TAKE OFF 20230201" y Regional Express se integra como un "facturar a" más de Avianca
-- =====================================================================================================================================================================
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_TotalCancellation](
	@AirportId INT,
	@CompanyId INT,
	@BillingToId INT,
	@ServiceTypeId INT,
	@ItineraryDate DATETIME2(0),
	@CancellationDate DATETIME2(0),
	@DateService DATE,
	@ServiceHeaderId BIGINT
)
RETURNS @T_RESULTADO TABLE(CollectServiceType BIT, ConsiderationPercentaje NVARCHAR(5), Consideration NVARCHAR(80))
AS
BEGIN

	--JETAIR / SAI
	IF (@CompanyId=295 AND @BillingToId=87) 
	BEGIN
		IF (@DateService >= '2023-05-09')
		BEGIN
			IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>-1440) --24 HORAS ANTES DEBEN AVISAR COMO MÁXIMO
			BEGIN
				INSERT @T_RESULTADO SELECT 1, '100%', NULL
				RETURN
			END 
			ELSE
			BEGIN
				INSERT @T_RESULTADO SELECT 0, NULL, NULL
				RETURN
			END
		END
	END

	--AEROMÉXICO / SAI
	IF (@CompanyId=58 AND @BillingToId=87) 
	BEGIN
		IF (@DateService >= '2023-05-09')
		BEGIN
			DECLARE @WeatherConditions BIT = [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_WeatherConditionsCancelation](@ServiceHeaderId)
			
			IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>-600 AND @WeatherConditions = 1) --10 HORAS ANTES DEBEN AVISAR COMO MÁXIMO Y EVENTOS DE FUERZA MAYOR
			BEGIN
				INSERT @T_RESULTADO SELECT 1, '30%', NULL
				RETURN
			END 
			ELSE IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>-600)
			BEGIN
				INSERT @T_RESULTADO SELECT 1, '40%', NULL
				RETURN
			END 
			ELSE
			BEGIN
				INSERT @T_RESULTADO SELECT 0, NULL, NULL
				RETURN
			END
		END
	END

	-- AMERICAN AIRLINES / SAI
	IF (@CompanyId=43 AND @BillingToId=87)
	BEGIN
		IF (@DateService >= '2023-05-09')
		BEGIN
			IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>-360) --6 HORAS ANTES DEBEN AVISAR COMO MÁXIMO
			BEGIN
				INSERT @T_RESULTADO SELECT 1, '50%', NULL
				RETURN
			END
			ELSE
			BEGIN
				INSERT @T_RESULTADO SELECT 0, NULL, NULL
				RETURN
			END
		END
	END

	--SPIRIT / SAI
	IF (@CompanyId=195 AND @BillingToId=87) 
	BEGIN
		IF (@DateService >= '2023-05-09')
		BEGIN
			IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>-720) --12 HORAS ANTES DEBEN AVISAR COMO MÁXIMO
			BEGIN
				INSERT @T_RESULTADO SELECT 1, '50%', NULL
				RETURN
			END
			ELSE
			BEGIN
				INSERT @T_RESULTADO SELECT 0, NULL, NULL
				RETURN
			END
		END
	END

	--ARAJET / ARAJET
	IF (@CompanyId = 272 AND @BillingToId = 272)
	BEGIN
		IF (@DateService >= '2022-09-15')
		BEGIN
			IF(DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate) BETWEEN -1440 AND -360) --ENTRE 24 Y 6 HORAS
			BEGIN
				INSERT @T_RESULTADO SELECT 1, '50%', '50% transito o pernocta (si no se notifico 12 hrs antes iti)'
				RETURN
			END

			IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>-720) --MENOS DE 6 DE HORAS DE ANTICIPACION
			BEGIN
				INSERT @T_RESULTADO SELECT 1, '100%', '100% transito o pernocta (si no se notifico 12 hrs antes iti)'
				RETURN
			END
		END
	END

	--ULTRA AIR / ULTRA AIR
	IF (@CompanyId = 259 AND @BillingToId = 259)
	BEGIN
		IF (@DateService >= '2022-01-20')
		BEGIN
			IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>-720) --12 HORAS ANTES DEBEN AVISAR COMO MÁXIMO
			BEGIN
				INSERT @T_RESULTADO SELECT 1, '50%', NULL
				RETURN
			END
			ELSE
			BEGIN
				INSERT @T_RESULTADO SELECT 0, NULL, NULL
				RETURN
			END
		END
	END

	-- SARPA A SARPA
	IF (@CompanyId = 69 AND @BillingToId = 69)
	BEGIN
		IF (@DateService >= '2021-10-01')
		BEGIN
			IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>-720) --12 HORAS ANTES DEBEN AVISAR COMO MÁXIMO
			BEGIN
				INSERT @T_RESULTADO SELECT 1, NULL, NULL
				RETURN
			END
			ELSE
			BEGIN
				INSERT @T_RESULTADO SELECT 0, NULL, NULL
				RETURN
			END
		END
	END

	--ADA
	IF (@CompanyId = 3 AND @BillingToId = 3)
	BEGIN
		IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>=-119)
		BEGIN
			INSERT @T_RESULTADO SELECT 1, NULL, NULL
			RETURN
		END
		ELSE
		BEGIN
			INSERT @T_RESULTADO SELECT 0, NULL, NULL
			RETURN
		END
	END

	--LAN/AIRES
	IF (@CompanyId IN (/*7,*/44) AND @BillingToId IN (/*7,*/44,139)) --LAN /AIRES, LAN PERU
	BEGIN
		IF (@DateService >= '2017-12-01' AND @AirportId IN (1, 52) AND @ServiceTypeId IN (24, 25)) --EN ADZ Y SMR A PATIR DE ESTA FECHA NO SE COBRAN CANCELACIONES PARA MTO TTO Y MTO PNTA
		BEGIN
			INSERT @T_RESULTADO SELECT 0, NULL, NULL
			RETURN
		END

		IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>=-179 AND @ServiceTypeId NOT IN (14) AND @AirportId = 25 AND @DateService >= '2021-10-27')  --EYP 3 HORAS ANTES
		BEGIN
			INSERT @T_RESULTADO SELECT 1, '75%', NULL
			RETURN
		END

		IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>=-119 AND @ServiceTypeId NOT IN (14))  --A LAN NO SE LE COBRAN LAS CANCELACIONES EN LIMPIEZA TERMINAL SEGÚN CORREO "RV: DEMORAS LIMPIEZA PERNOCTA LAN"
		BEGIN
			INSERT @T_RESULTADO SELECT 1, NULL, NULL
			RETURN
		END

		--REGLA POR DEFECTO NO SE COBRA
		INSERT @T_RESULTADO SELECT 0, NULL, NULL
		RETURN
	END
	
	--LC PERU / AVENTURS
	IF (@CompanyId = 66 AND @BillingToId = 89)
	BEGIN
		IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>=-119)
		BEGIN
			INSERT @T_RESULTADO SELECT 1, NULL, NULL
			RETURN
		END
		ELSE
		BEGIN
			INSERT @T_RESULTADO SELECT 0, NULL, NULL
			RETURN
		END
	END

	--SATENA/GAMMA
	IF (@CompanyId = 37 AND @BillingToId = 36)
	BEGIN
		IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>=-119)
		BEGIN
			INSERT @T_RESULTADO SELECT 1, NULL, NULL
			RETURN
		END
		ELSE
		BEGIN
			INSERT @T_RESULTADO SELECT 0, NULL, NULL
			RETURN
		END
	END

	--WINGO
	IF (@CompanyId = 72 AND @BillingToId = 56)
	BEGIN
		IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>=-119 AND @ServiceTypeId NOT IN (24, 25))
		BEGIN
			INSERT @T_RESULTADO SELECT 1, NULL, NULL
			RETURN
		END
		ELSE
		BEGIN
			INSERT @T_RESULTADO SELECT 0, NULL, NULL
			RETURN
		END
	END

	--COPA
	IF (@CompanyId = 9 AND @BillingToId IN (9, 56))
	BEGIN
		IF (@AirportId = 1 AND @ServiceTypeId IN (24,25))
		BEGIN
			INSERT @T_RESULTADO SELECT 0, NULL, NULL --LAS CANCELACIONES DE MANTENIMIENTO NO SE COBRAN EN ADZ CON COPA
			RETURN
		END
		ELSE
		BEGIN
			IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>=-119)
			BEGIN
				INSERT @T_RESULTADO SELECT 1, NULL, NULL
				RETURN
			END
			ELSE
			BEGIN
				INSERT @T_RESULTADO SELECT 0, NULL, NULL
				RETURN
			END
		END
	END

	--EASY FLY
	IF (@CompanyId = 11 AND @BillingToId = 11)
	BEGIN
		IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>=-119)
		BEGIN
			INSERT @T_RESULTADO SELECT 1, NULL, NULL
			RETURN
		END
		ELSE
		BEGIN
			INSERT @T_RESULTADO SELECT 0, NULL, NULL
			RETURN
		END
	END

	--VIVA COLOMBIA Y VIVA PERU
	IF ((@CompanyId = 60 AND @BillingToId = 90) OR (@CompanyId = 192 AND @BillingToId = 192))
	BEGIN
		IF (CONVERT(DATE, @ItineraryDate) >= '2016-06-01') --DESDE EL INICIO DE JUNIO DE 2016
		BEGIN
			IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>-720 AND @ServiceTypeId NOT IN(24,25,27,28,29)) --12 HORAS ANTES DEBEN AVISAR COMO MÁXIMO
			BEGIN
				INSERT @T_RESULTADO SELECT 1, NULL, NULL
				RETURN
			END
			ELSE
			BEGIN
				INSERT @T_RESULTADO SELECT 0, NULL, NULL
				RETURN
			END
		END

		INSERT @T_RESULTADO SELECT 0, NULL, NULL --A VIVA COLOMBIA NO SE LE COBRABAN CANCELACIONES ANTES SI ES VERDAD NO SE LE COBRABAN AUNQUE SUENE EXTRAÑO
		RETURN
	END

	--JET SMART
	IF (@CompanyId = 81 AND @BillingToId = 81)
	BEGIN		
		IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>-720 ) --12 HORAS ANTES DEBEN AVISAR COMO MÁXIMO
		BEGIN
			INSERT @T_RESULTADO SELECT 1, '50%', NULL
			RETURN
		END
		ELSE
		BEGIN
			INSERT @T_RESULTADO SELECT 0, NULL, NULL
			RETURN
			
		END	
	END

	--GRAN COLOMBIA DE AVIACION (GCA)
	IF (@CompanyId = 228 AND @BillingToId = 228)
	BEGIN		
		IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>-120 ) --2 HORAS ANTES DEBEN AVISAR COMO MÁXIMO
		BEGIN
			INSERT @T_RESULTADO SELECT 1, '50%', NULL
			RETURN
		END
		ELSE
		BEGIN
			INSERT @T_RESULTADO SELECT 0, NULL, NULL
			RETURN
			
		END	
	END

	--CON AVIATECA EN ADZ NO SE COBRAN DEMORAS EN MTO TTO Y MTO PNTA
	IF (@BillingToId = 91 AND @ServiceTypeId IN (24, 25) AND @AirportId = 1)
	BEGIN
		INSERT @T_RESULTADO SELECT 0, NULL, NULL
		RETURN
	END

	IF	(	(	(@CompanyId = 1 AND @BillingToId = 1) --AVIANCA A AVIANCA	
		OR	(@CompanyId = 193 AND @BillingToId = 1) --REGIONAL EXPRESS A AVIANCA
		OR	(@CompanyId = 47 AND @BillingToId = 1) --AEROGAL A AVIANCA
		OR	(@CompanyId = 42 AND @BillingToId = 42) --TACA A TACA 
		) AND @DateService >= '2023-02-01'
	) 
	BEGIN
		IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>=-239)
		BEGIN
			INSERT @T_RESULTADO SELECT 1, '20%', '20% transito o pernocta (si no se notifico 4 hrs antes iti)'
			RETURN
		END
	END 

	IF	(	(	(@CompanyId = 1 AND @BillingToId = 1) --AVIANCA A AVIANCA		
		OR	(@CompanyId = 47 AND @BillingToId = 1) --AEROGAL A AVIANCA
		OR	(@CompanyId = 42 AND @BillingToId = 42) --TACA A TACA 
		OR	(@CompanyId = 42 AND @BillingToId = 54) --TACA A TRANSAMERICAN 
		OR	(@CompanyId = 41 AND @BillingToId = 41) --LACSA A LACSA
		OR	(@BillingToId = 1 AND @CompanyId <> 193) --COMPAÑIAS QUE SE FACTURAN A AVIANCA SERVICES
		) AND @DateService <= '2023-01-31'
	) 
	BEGIN
		IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>=-239)
		BEGIN
			INSERT @T_RESULTADO SELECT 1, '30%', '30% transito o pernocta (si no se notifico 4 hrs antes iti)'
			RETURN
		END
	END 

	/*** Ajuste solicitado por contabilidad (Patricia) ***/

	IF	(@CompanyId = 193 AND @BillingToId = 1 AND (@DateService < '2019-12-01' OR @AirportId IN (3,45) /*MDE - PEI*/)) --REGIONAL EXPRESS AMERICAS A AVIANCA
	 BEGIN
		  IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>=-239)
		  BEGIN
			INSERT @T_RESULTADO SELECT 1, '30%', '30% transito o pernocta (si no se notifico 4 hrs antes iti)'
			RETURN
		  END		
	END

	IF	(@CompanyId = 193 AND @BillingToId = 1 AND @DateService >= '2019-12-01' AND @AirportId NOT IN (3,45) /*MDE - PEI*/) --REGIONAL EXPRESS AMERICAS A AVIANCA
	 BEGIN
		  IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>=-119)
		  BEGIN
			INSERT @T_RESULTADO SELECT 1, '20%', '20% transito o pernocta (si no se notifico 2 hrs antes iti)'
			RETURN
		  END
		  ELSE 
		  BEGIN 
		    INSERT @T_RESULTADO SELECT 0, NULL, NULL
			RETURN
		  END

	END

	IF	(@CompanyId = 255 AND @BillingToId = 255) --VIVAAEROBUS
	 BEGIN
		IF (CONVERT(DATE, @ItineraryDate) >= '2021-08-21')
		BEGIN
			IF(DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate) BETWEEN -720 AND -360) --ENTRE 12 Y 6 HORAS
			BEGIN
				INSERT @T_RESULTADO SELECT 1, '50%', '50% transito o pernocta (si no se notifico 12 hrs antes iti)'
				RETURN
			END

			IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>-720) --MENOS DE 6 DE HORAS DE ANTICIPACION
			BEGIN
				DECLARE @WeatherConditionsCancelation BIT = [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_WeatherConditionsCancelation](@ServiceHeaderId)
				DECLARE @PaxCanceled BIT = ISNULL((SELECT CASE WHEN TotalPaxCancelados > 0 THEN 1 ELSE 0 END PaxCanceled FROM [CIOReportes].[UFN_CIO_Report_PaxService](@DateService, @DateService, @AirportId, @CompanyId, @BillingToId, @ServiceHeaderId)), 0)

				IF (@WeatherConditionsCancelation = 1) --Si fue cancelado por mal tiempo
				BEGIN
					IF (@PaxCanceled = 1) --Si en el módulo se cancelaron 1 o más pasajeros
					BEGIN
						INSERT @T_RESULTADO SELECT 1, '50%', '50% transito o pernocta (si no se notifico 6 hrs antes iti y mal tiempo)'
						RETURN
					END
				END
				ELSE
				BEGIN
					INSERT @T_RESULTADO SELECT 1, '100%', '100% transito o pernocta (si no se notifico 6 hrs antes iti)'
				END
				RETURN
			END

			RETURN
		END
	END

	--REGLA POR DEFECTO APLICA SI NO APLICA NINGUNA DE LAS COMPAÑIAS ANTERIORES
	IF (DATEDIFF(MINUTE,@ItineraryDate,@CancellationDate)>=-239)
	BEGIN
		INSERT @T_RESULTADO SELECT 1, NULL, NULL
		RETURN
	END

	INSERT @T_RESULTADO SELECT 0, NULL, NULL --SI NO SE CUMPLE NINGUNA
	RETURN 
END